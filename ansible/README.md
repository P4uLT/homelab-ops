# ansible/

Runtime configuration for the homelab: one hub-and-spoke playbook tree,
one inventory, three host populations with separate authorities.

## Layout

| Path | Purpose |
| ---- | ------- |
| `config/` | `ansible.cfg` (symlinked at `ansible/` for auto-discovery), logs, retry files, project `known_hosts` |
| `requirements.yml` | Vendor pins: roles + collections (single galaxy source) |
| `inventory/` | `servers/` — `groups.yml` (tree), `hosts.yml` (membership), `iac.tf.yml` (TF placeholder) — with adjacent `group_vars/` |
| `inventory/servers/group_vars/` | Variables per inventory group (cleartext vars + `*.sops.yaml` secrets) |
| `playbooks/` | Hub (`site.yml`), orchestrators (`main/`), spokes, `verify.yml` |
| `roles/` | `local/` (ours), `profiles/` (composable baselines), `vendors/` (downloaded, ignored) |
| `collections/` | `local/` (ours), `vendors/` (downloaded, ignored except the marker) |
| `plugins/` | Local filter, lookup, callback, and module code |
| `vars/` | Variable files loaded explicitly by name |

## Populations

- **Cattle** — LXC born from a Packer golden image via Terraform. The image
  owns the OS baseline. Patching means rebuilding the image. Do not upgrade
  a cattle node in place. Playbooks guard on `/etc/image-build-info` and skip
  the baseline for cattle.
- **Pets by nature** — hosts that carry state or hardware and cannot be
  rebuilt from an image: `pve-one`, TrueNAS, OMV. They get the full
  baseline.
- **Manual LXC** (`grp_lxc_manual`) — containers created by hand in the PVE
  UI, outside the TF+Packer pipeline. They get the full baseline.

Talos nodes are out of scope for Ansible: no SSH, no playbooks, ever.

## Verify

The shell proves itself without any managed host:

```console
task verify
```

That runs `uv sync`, the playbook syntax passes, `ansible-lint`, and the
verification playbook against the `inventory/servers` inventory (localhost,
local connection, no managed-host contact, no credentials).
