# ansible/

Runtime configuration for the homelab: one hub-and-spoke playbook tree,
one inventory, three host populations with separate authorities.

## Layout

| Path | Purpose |
| ---- | ------- |
| `ansible.cfg` | Points to the local roles, collections, plugins, retry, and log paths |
| `inventory/` | `local.yml` (verification), `servers/` (static pets + generated `iac.tf.yml`) |
| `group_vars/` | Variables per inventory group |
| `playbooks/` | Hub (`site.yml`), orchestrators (`main/`), spokes, `verify.yml` |
| `roles/` | `local/` (ours), `profiles/` (composable baselines), `vendors/` (downloaded, ignored) |
| `collections/` | `local/` (ours), `vendors/` (downloaded, ignored except the marker) |
| `plugins/` | Local filter, lookup, callback, and module code |
| `config/tmp/` | Retry files and logs (git-ignored) |
| `vars/` | Variable files loaded explicitly by name |

## Populations

- **Cattle** — LXC born from a Packer golden image via Terraform. The image
  owns the OS baseline; patching means rebuilding the image, never an
  in-place upgrade. Playbooks guard on `/etc/image-build-info` and skip the
  baseline for cattle.
- **Pets by nature** — hosts that carry state or hardware and cannot be
  rebuilt from an image: `pve-one`, TrueNAS, OMV. They get the full
  baseline.
- **Manual LXC** (`grp_lxc_manual`) — containers created by hand in the PVE
  UI, outside the TF+Packer pipeline. They get the full baseline.

Talos nodes are out of scope for Ansible: no SSH, no playbooks, ever.

## Verify

The shell proves itself without any managed host:

```console
task -d ansible verify
```

That runs `uv sync`, a syntax check, `ansible-lint`, and the verification
playbook against `inventory/local.yml` (localhost, local connection, no
SSH, no become, no credentials).
