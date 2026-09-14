# ansible/

Configuration as code for the homelab: one hub-and-spoke playbook tree plus
the golden image builds, two inventories, three host populations with
separate authorities.

## Layout

| Path | Purpose |
| ---- | ------- |
| `config/` | `ansible.cfg` (symlinked at `ansible/` for auto-discovery), logs, retry files, project `known_hosts` |
| `requirements.yml` | Vendor pins: roles + collections (single galaxy source) |
| `inventory/` | `servers/`: `groups.yml` (tree), `hosts.yml` (membership), `iac.tf.yml` (TF placeholder), with adjacent `group_vars/`. `builders/`: the Packer build containers, one host per image |
| `inventory/servers/group_vars/` | Variables per inventory group (cleartext vars + `*.sops.yaml` secrets) |
| `playbooks/` | Hub (`site.yml`), orchestrators (`main/`), spokes, `image.yml` (the golden image builds, run by Packer through the `image` recipe), `verify.yml` |
| `roles/` | `local/` (ours, hand-written), `vendors/` (downloaded, exact pins, ignored) |
| `collections/` | `local/` (ours), `vendors/` (downloaded, ignored except the marker) |
| `plugins/` | Local filter, lookup, callback, and module code |
| `vars/` | Variable files loaded explicitly by name |

## Populations

- **Cattle**: LXC born from a Packer golden image via Terraform. The image
  owns the OS baseline, and no secret, key, or credential is ever baked into
  it. Patching means rebuilding the image. Don't upgrade a cattle node in
  place. The common spoke asserts `/etc/image-build-info` for cattle and skips
  the baseline. The `bootstrap` spoke does their application wiring.
- **Pets by nature**: the PVE hosts, the NAS, and any appliance that carries
  state or hardware and can't be rebuilt from an image.
- **Manual LXC** (`grp_lxc_manual`): containers created by hand in the PVE
  UI, outside the TF+Packer pipeline.

Populations don't decide the baseline by themselves. Every non-cattle host
applies the roles its group lists in `common_profiles`, a variable that lives
in that group's `group_vars`. No group defines it yet, so no host is changed
by the common spoke today.

## Services

A service is opt-in per inventory group, independent of the population. The
group lists who runs it, the play lives in `playbooks/servers/services/`, and
the golden images call the same vendor role with the same policy from
`playbooks/image/`. `grp_docker` is the first one, empty until a host joins
it.

Talos nodes are out of scope for Ansible: no SSH, no playbooks, ever.

## Verify

The shell proves itself without any managed host:

```console
task ansible:verify
```

That runs `uv sync`, the galaxy install, the syntax passes, `ansible-lint`,
the SOPS canary, and the verification playbook. The syntax passes cover the
servers playbooks and the image entry point with its own inventory. The
verification playbook runs against `inventory/servers` on localhost, with no
credentials and no managed-host contact. The canary needs the age key, so a
keyless clone stops there. The repository-wide `task verify` adds the docs,
Terraform, and Packer legs, and still contacts no host.
