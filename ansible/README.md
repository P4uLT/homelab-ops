# ansible/

Configuration as code for the homelab: one entry point per run, one layer per
scope, two inventories, three host populations with separate authorities.

## Layout

| Path | Purpose |
| ---- | ------- |
| `config/` | `ansible.cfg` (symlinked at `ansible/` for auto-discovery), logs, retry files, project `known_hosts` |
| `requirements.yml` | Vendor pins: roles + collections (single galaxy source) |
| `inventory/` | `servers/`: the machines Ansible manages, with `groups.yml` (tree) and `hosts.yml` (membership). A Terraform-created container lands here as a generated group, written by the workload root. `builders/`: the Packer build containers, one host per image. Group names read `grp_<scope>_<specifics>`: `grp_servers_*` for the machine tree, `grp_builders_*` for the build containers, `grp_services_*` for opt-in service memberships |
| `inventory/*/group_vars/` | Each inventory owns its own. One directory per group that carries variables, named after the group: `vars.yml` for cleartext, `secrets.sops.yaml` for secrets. A directory holds one or both |
| `playbooks/` | Two tracks, two entries. `site.yml` runs `servers/`, the fleet layers `common`, `monitoring`, `services`, `stacks`, plus `bootstrap`. `image.yml` runs `image/`, the build chain: `common/base.yml` is the track's common. `services/<name>.yml` and `stacks/<name>.yml` hold the images that add a service or a whole stack. Two entries on purpose: a build seals its container, and the fleet entry must never seal a live machine. `verify.yml` proves the shell |
| `roles/` | `local/` (ours, hand-written), `vendors/` (downloaded, exact pins, ignored) |
| `collections/` | `local/` (ours), `vendors/` (downloaded, ignored except the marker) |
| `plugins/` | Local filter, lookup, callback, and module code |
| `vars/` | Variable files loaded explicitly by name. Empty today |

## Populations

- **Cattle**: LXC born from a Packer golden image via Terraform. Each one
  joins the fleet as `grp_tf_<host>` under `grp_servers`, the family the
  common layer keys on. The image owns the OS baseline, and no secret, key,
  or credential is ever baked into it. A fresh container gets its keys at
  first contact.
  [Provision an LXC workload](../docs/runbooks/provision-pve-ct.md) walks
  through it. Patching means rebuilding the image. Don't upgrade a cattle node in
  place. The common layer asserts `/etc/image-build-info` for cattle and skips
  the baseline. The `bootstrap` playbook does their application wiring.
- **Pets by nature**: the PVE hosts, the NAS, and any appliance that carries
  state or hardware and can't be rebuilt from an image.
- **Manual LXC** (`grp_lxc_manual`): containers created by hand in the PVE
  UI, outside the TF+Packer pipeline.

Populations don't decide the baseline by themselves. Every non-cattle host
applies the roles its group lists in `common_profiles`, a variable that lives
in that group's `group_vars`. No group defines it yet, so no host is changed
by the common layer today.

## Services

A service is opt-in per inventory group, independent of the population. The
group lists who runs it, and both tracks call the same locL'idée c'est d'avoir la même chose dans les deux, serveur et image. Stacks, cela permet de déployer des stacks complètes, 4 versus... al role. The
runtime runs `servers/services/docker.yml`. The golden image build runs
`image/services/docker.yml`. The role carries the mechanism. Each inventory
declares the policy in its own `group_vars/<group>/vars.yml`, because Ansible
shares no group_vars between inventories. `grp_services_docker` is the first
one, empty until a host joins it.

Talos nodes are out of scope for Ansible: no SSH, no playbooks, ever.

## Verify

The shell proves itself without any managed host:

```console
task ansible:verify
```

That runs `uv sync`, the galaxy install, the syntax passes, `ansible-lint`,
the SOPS canary, and the verification playbook. The syntax passes cover the
fleet track, the converge play, and the image entry with its own inventory. The
verification playbook runs against `inventory/servers` on localhost, with no
credentials and no managed-host contact. The canary needs the age key, so a
keyless clone stops there. The repository-wide `task verify` adds the docs,
Terraform, and Packer legs, and still contacts no host.
