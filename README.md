# homelab-ops

**Every workload starts from a versioned golden image, provisioned and configured as code**

Use it as a reference for the Packer, OpenTofu, and Ansible pipeline on Proxmox VE, or run it against your own nodes.

## Install

```bash
git clone https://github.com/P4uLT/homelab-ops.git
cd homelab-ops
mise install
```

The pinned toolchain comes from [mise](https://mise.jdx.dev), `task` included.

## Quickstart

### Without the secrets

The prose gate runs on a fresh clone. It needs no network and no secret:

```bash
task docs:check    # Vale over every tracked file
```

`task --list` shows the rest of the task surface.

### With the secrets

The full gate reads two git-ignored files: the age key at `.age.key.txt` and
the state passphrase in `.env.tf`. [SOPS procedures](docs/sops.md) cover the
key, and [the state backend design](terraform/BACKEND.md) covers the passphrase.

```bash
task ansible:galaxy    # vendor roles and collections, network on the first run
task tf:init           # OpenTofu providers, and the encrypted state
task packer:init       # Packer plugins
task verify            # the whole local gate
```

## How it works

Four parts, one image lineage:

- **Packer:** builds golden LXC images on each PVE node and stores the archive
  in the template cache. Images chain, and each one pins its parent.
- **OpenTofu:** provisions a workload by cloning a golden image, one root per
  server. State lives on OVH S3, encrypted with AES-GCM and covered by a
  lockfile.
- **Ansible:** provisions the golden images at build time and converges the
  runtime configuration of each host, from one role set. Secrets stay in SOPS
  files encrypted with age, and a canary variable loads on every inventory
  run, so a run without the key fails loudly.
- **Kubernetes:** holds the Talos and Flux lab for the bare-metal nodes. Not
  populated yet: the tree holds a placeholder.

## What's inside

| Path | What it holds |
| ---- | ------------- |
| [`packer/`](packer/README.md) | Golden LXC images, one build per PVE node |
| [`terraform/`](terraform/README.md) | OpenTofu roots: the OVH state backend, PVE access, and one root per server |
| [`ansible/`](ansible/README.md) | Inventory, playbooks, roles, and SOPS-encrypted variables |
| [`kubernetes/`](kubernetes/README.md) | Talos and Flux lab, a later phase |
| [`lab/`](lab/README.md) | Experiments, not production |
| [`docs/`](docs/README.md) | Index, reference pages, and runbooks |

## Notes

- The repository is public and holds no cleartext secret. Every secret lives
  in a SOPS file, encrypted with age.
- `task verify` runs offline after the first downloads. Both files in the
  quickstart stay on the machine and out of git.
- Check mode can change a node. Get owner approval before any host contact.
- Patterns in the LXC module come from
  [`trfore/terraform-bpg-proxmox`](https://github.com/trfore/terraform-bpg-proxmox)
  (Apache-2.0).

## License

[MIT](LICENSE)
