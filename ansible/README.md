# ansible/

Ansible configuration with separate entry points and inventories for server
maintenance, image builds, and machine onboarding.

## Layout

| Path | Purpose |
| --- | --- |
| `config/` | `ansible.cfg`, symlinked at `ansible/` for auto-discovery, plus logs, retry files, and project `known_hosts` |
| `requirements.yml` | Role and collection pins for Galaxy |
| `inventory/servers/` | Managed machines. `groups.yml` defines the tree and `hosts.yml` defines membership. Workload roots generate inventory fragments for Terraform-created LXC containers |
| `inventory/builders/` | Packer build containers, one host per image |
| `inventory/*/group_vars/` | Variables beside each inventory. Each group directory contains `vars.yml`, `secrets.sops.yaml`, or both |
| `playbooks/site.yml` | Server system configuration and opt-in services |
| `playbooks/image.yml` | Image build chain: `image/base.yml`, `image/services/<name>.yml`, and `image/stacks/<name>.yml` |
| `playbooks/bootstrap.yml` | One-time account creation, access verification, and password-login closure |
| `playbooks/verify.yml` | Local verification |
| `roles/`, `collections/` | Tracked `local/` content and pinned, ignored `vendors/` content. Collection vendor markers remain tracked |
| `plugins/` | Local filters, lookups, callbacks, and modules |
| `vars/` | Explicitly loaded variable files, empty |

Group names use `grp_<scope>_<specifics>`: `grp_servers_*` for maintenance
populations, `grp_image_builders_*` for builders, and `grp_services_*` for services.
Keep the entry points separate. Image builds seal containers, and onboarding
sets `ansible_user` for a temporary connection identity.

A layer has an `all.yml` router and one file per concern. Run a concern with
`task ansible:playbook`. Keep single-command checks in one file.

## Roles and parameters

Playbooks select and order roles. Reuse a suitable role before adding a
parallel task or an installation-specific wrapper.

| Role | Contract |
| --- | --- |
| [apt](roles/local/apt/README.md) | Local adoption of WeAreInteractive's Advanced Package Tool (APT) role. Inventory selects packages and upgrades. Image preparation uses `apt_cache_valid_time: 0` to refresh a potentially empty sealed cache |
| [fleet_account](roles/local/fleet_account/README.md) | Install `sudo` with upgrades off, then pass a nonempty `fleet_account_users` list to `robertdebock.users`. Callers bind their inventory's `fleet_users` |
| [image_bootstrap](roles/local/image_bootstrap/README.md) | Install the module interpreter and verify the build-container identity |
| [image_finalize](roles/local/image_finalize/README.md) | Seal the image after provisioning |
| [systemd](roles/local/systemd/README.md) | Manage existing services from `systemd_services`, without creating units or installing dependencies. Privilege escalation belongs to the caller |

The [provenance record](roles/local/apt/UPSTREAM.md) specifies its source
and local changes. Server calls use the default cache lifetime.
Population packages belong in inventory `group_vars`. The Debian LXC and
base-image groups select `curl` and `ca-certificates`.
Docker and Proxmox use their vendor role interfaces and repository setup.

The static `container_service_units` lists in `grp_servers_lxc` and
`grp_image_builders_base` bind to `systemd_services` at the call site.
They stop and disable `systemd-networkd-wait-online.service` when present,
without masking it. Omitted actions leave existing settings unchanged.

## Populations

- **Image-derived workloads:** Terraform clones a Packer image and generates
  a `grp_servers_immutable_<host>` leaf under `grp_servers_immutable`.
  The image defines the OS baseline. Rebuild to change it instead of upgrading
  the OS in place. Follow [Provision an LXC workload](../docs/runbooks/provision-pve-ct.md).
- **Mutable servers:** `grp_servers_mutable` contains `grp_servers_lxc` and
  `grp_servers_proxmox`. Debian LXC hosts use `grp_servers_lxc_debian` for
  package policy. Proxmox nodes don't join that group.
- **Manual Debian LXC:** use a leaf such as `grp_servers_lxc_<host>` under
  `grp_servers_lxc_debian`.

Mutable and immutable membership must be disjoint. Group names must be unique
within an inventory. Packer defines artifact inheritance across separate
builder and server inventories, without Ansible group inheritance.

Before system configuration, `playbooks/servers/system/workload_preflight.yml`
requires an explicit, nonblank workload address and a regular image marker file.
Store the address in the workload group's encrypted variables.
Preflight validates file type only, without marker contents or image provenance.

Onboard a raw machine with `task ansible:onboard HOST=<node> IDENTITY=<raw>`.
Convergence requires `HOST`, as in `task ansible:converge HOST=jarvis` or
`task ansible:converge-check HOST=jarvis`.
Use `HOST=grp_servers_proxmox` only for an intended group-wide run.

## Services

Service membership is opt-in and independent of maintenance populations.
`grp_services_docker` selects runtime Docker recipients. The runtime play is
`servers/services/docker.yml`, and the image play is `image/services/docker.yml`.
Both use the same vendor role, with policy in their own inventory's
`group_vars/<group>/vars.yml`. Variables aren't shared between inventories.

In builders, `builder-docker` joins `grp_services_docker` for policy.
`grp_image_builders_docker` and Packer's host limit select its recipe.
The Docker call refreshes the apt index from the sealed parent before
installing Debian dependencies. Packer selects its parent artifact.

Talos nodes don't use Ansible or SSH.

## Verify

```console
task ansible:verify
```

This runs `uv sync`, Galaxy installation, syntax checks, `ansible-lint`, the
SOPS canary, and `verify.yml`. Syntax checks cover the fleet, convergence, and
image entry with its builders inventory. The verification playbook uses
`inventory/servers` on localhost without connection credentials.
The canary requires the age key. Without it, inventory loading fails.
`task verify` also checks docs, Terraform, and Packer without managed-host contact.

Local checks don't apply packages or services to managed machines.
Get approval before verifying live behavior and idempotence. Apply the role
on its target, then repeat it and expect `changed=0`.
