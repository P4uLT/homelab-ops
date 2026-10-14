# ansible/

Configuration as code for the homelab: one entry point per run, one layer per
scope, and separate inventories for servers and image builders.

## Layout

| Path | Purpose |
| ---- | ------- |
| `config/` | `ansible.cfg` (symlinked at `ansible/` for auto-discovery), logs, retry files, project `known_hosts` |
| `requirements.yml` | Vendor pins: roles + collections (single galaxy source) |
| `inventory/` | `servers/`: the machines Ansible manages, with `groups.yml` (tree) and `hosts.yml` (membership). A Terraform-created container lands here as a generated group, written by the workload root. `builders/`: the Packer build containers, one host per image. Group names read `grp_<scope>_<specifics>`: `grp_servers_*` for server maintenance populations, `grp_image_builders_*` for Packer builders, and `grp_services_*` for opt-in service memberships |
| `inventory/*/group_vars/` | Each inventory owns its own. One directory per group that carries variables, named after the group: `vars.yml` for cleartext, `secrets.sops.yaml` for secrets. A directory holds one or both |
| `playbooks/` | Three entries, each unreachable from the others. `site.yml` runs `servers/system/` and `servers/services/`. `image.yml` runs the image build chain. `bootstrap.yml` runs `bootstrap/`, the one-time onboarding of a raw machine: the account, the proof it works, and password login closed. `image/base.yml` is the base-image recipe, `services/<name>.yml` adds a service to an image, and `stacks/<name>.yml` ships a whole stack. The entries stay separate on purpose. A build seals its container, and the adopting play sets `ansible_user`, which would otherwise override every host's steady identity. `verify.yml` proves the shell |
| `roles/` | `local/` (original or adopted source, tracked), `vendors/` (downloaded, exact pins, ignored) |
| `collections/` | `local/` (ours), `vendors/` (downloaded, ignored except the marker) |
| `plugins/` | Local filter, lookup, callback, and module code |
| `vars/` | Variable files loaded explicitly by name. Empty today |

A layer is a directory behind an `all.yml` router. Each concern gets a file,
so a topic is found by its name and runs alone with `task ansible:playbook`.
A check that runs as one command stays one file.

## Roles and parameters

A role owns a reusable capability. A playbook selects roles and orders their
calls. Modules implement the operations inside each role. Reuse a fitting role
before adding a parallel task or a role for one installation.

The [apt role](roles/local/apt/README.md) adopts WeAreInteractive's Advanced Package Tool (APT) role.
Its [provenance record](roles/local/apt/UPSTREAM.md) pins the source revision and documents local changes.
Existing callers retain package, upgrade, and cache inputs.
Defaults select no population packages or upgrades and ensure the `python3-apt` dependency.
Global configuration, service-start restrictions, cleanup, and unattended upgrades require explicit inputs.
Image preparation keeps `apt_cache_valid_time: 0` because an empty cache can carry a recent timestamp.
Server calls retain the default cache lifetime.

Population policy belongs in each inventory's `group_vars`. The Debian LXC and base-image groups list `curl` and `ca-certificates`.

The [fleet account role](roles/local/fleet_account/README.md) requires a non-empty
`fleet_account_users` list in the
`robertdebock.users` format. Each caller binds its inventory's `fleet_users` at
the role call. The role installs `sudo` through `apt`, with upgrades off, then
calls `robertdebock.users`. Adoption, runtime, and image builds share that
contract. The prerequisite isn't part of a population's package policy.

A composition role owns a shared invariant, not another copy of a vendor's
interface. The image roles own [interpreter bootstrap](roles/local/image_bootstrap/README.md)
and [sealing](roles/local/image_finalize/README.md).

The [systemd role](roles/local/systemd/README.md) manages existing services through the native module.
Its typed `systemd_services` list accepts boot enablement, runtime state, and explicit absence policy.
An empty list changes no services. Omitted actions leave their settings unchanged.
The two inventories declare static `container_service_units` lists in `grp_servers_lxc` and `grp_image_builders_base`.
Each caller binds that population to `systemd_services`.
The container profile stops and disables `systemd-networkd-wait-online.service` when present, without masking it.
The role doesn't create unit files or add dependencies. Privilege escalation stays with the caller.
Docker and Proxmox keep their vendor interfaces and their repository setup.

## Populations

- **Image-derived workloads**: Terraform creates an LXC from a Packer image.
  Each joins `grp_servers_immutable` through a `grp_servers_immutable_<host>`
  leaf, so the leaf repeats its parent's name.
  The image owns its operating-system baseline. `playbooks/servers/system/workload_preflight.yml`
  requires an explicit, nonblank address and a regular image marker file before system configuration.
  It doesn't validate the marker's contents or image provenance. Store the address in that
  workload group's encrypted variables. Rebuild a workload to change its image.
  Don't upgrade its operating system in place. [Provision an LXC workload](../docs/runbooks/provision-pve-ct.md)
  walks through the process.
- **Mutable servers**: `grp_servers_mutable` contains systems maintained by
  Ansible. Its current branches are `grp_servers_lxc` and
  `grp_servers_proxmox`. Debian LXC hosts join `grp_servers_lxc_debian` for
  package policy. Proxmox nodes stay outside that group. Use
  `task ansible:onboard HOST=<node> IDENTITY=<raw>` to onboard a raw machine.
- **Manual LXC**: a manually created Debian container joins a leaf such as
  `grp_servers_lxc_<host>` under `grp_servers_lxc_debian`.

Mutable and immutable membership stays disjoint. Each group name has one
identity in an inventory. The image-build inventory stays separate from the
server inventory. Packer passes the Docker image's parent artifact. Ansible
group inheritance doesn't connect the two image recipes.

The convergence tasks require an explicit `HOST`, such as
`task ansible:converge HOST=jarvis` or
`task ansible:converge-check HOST=jarvis`. Use
`HOST=grp_servers_proxmox` only for a deliberate group-wide run.

## Services

A service is opt-in per inventory group, independent of the population. The
group lists who runs it, and both tracks call the same vendor role. The
runtime runs `servers/services/docker.yml`. The golden image build runs
`image/services/docker.yml`. The role carries the mechanism. Each inventory
declares the policy in its own `group_vars/<group>/vars.yml`, because Ansible
shares no group_vars between inventories. `grp_services_docker` selects runtime Docker recipients in the server inventory.
In the builders inventory, `builder-docker` joins the same service group for
Docker policy. Its recipe is selected by `grp_image_builders_docker` and Packer's
`builder-docker` host limit. The Docker artifact inherits its base through
Packer, not through Ansible group membership. The Docker image call refreshes
the apt index from its sealed parent before the vendor installs Debian dependencies.

Talos nodes are out of scope for Ansible: no SSH, no playbooks, ever.

## Verify

The shell proves itself without any managed host:

```console
task ansible:verify
```

That runs `uv sync`, the galaxy install, the syntax passes, `ansible-lint`,
the SOPS canary, and the verification playbook. The syntax
passes cover the fleet track, the converge play, and the image entry with its
own inventory. The
verification playbook runs against `inventory/servers` on localhost, with no
credentials and no managed-host contact. The canary needs the age key, so a
keyless clone stops there. The repository-wide `task verify` adds the docs,
Terraform, and Packer legs, and still contacts no host.

These checks read the content. They install no package and change no machine.
Prove a role's behavior on a target before claiming it there: run its play, then
repeat the apply and require no change. That run needs owner approval.
A syntax pass and a lint report never prove idempotence.
