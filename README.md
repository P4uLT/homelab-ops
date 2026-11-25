# homelab-ops

Infrastructure as code for Proxmox VE, using versioned golden images,
OpenTofu, and Ansible.

Use this repository to build images, provision workloads, and configure hosts.

## Install

Install the pinned toolchain, including `task`, with [mise](https://mise.jdx.dev):

```bash
git clone https://github.com/P4uLT/homelab-ops.git
cd homelab-ops
mise install
```

## Quickstart

Check prose offline without secrets, or list the available tasks:

```bash
task docs:check
task --list
```

Full verification needs the age key in `.age.key.txt` and OpenTofu backend
values in `.env.tf`. Both files are git-ignored. See [SOPS setup](docs/sops.md)
and the [state backend design](terraform/BACKEND.md).

Install dependencies once, then run the local checks:

```bash
task ansible:galaxy    # roles and collections
task tf:init           # providers and encrypted state
task packer:init       # plugins
task verify
```

The first downloads need network access. Afterward, `task verify` runs offline.
Get owner approval before contacting a node, including check mode, which can
change it.

## Components

| Path | Purpose |
| --- | --- |
| [`packer/`](packer/README.md) | Golden LXC images per PVE node. Each image pins its parent and stores its archive in the template cache |
| [`terraform/`](terraform/README.md) | LXC clones and imported-image VMs, one root per server. OVH S3 state with AES-GCM encryption and a lockfile. Includes the state and PVE access bootstrap roots |
| [`ansible/`](ansible/README.md) | Image provisioning and host configuration from shared roles. Inventory runs load a SOPS canary and fail without the age key |
| [`kubernetes/`](kubernetes/README.md) | Placeholder for the Talos and Flux lab on bare-metal nodes |
| [`lab/`](lab/README.md) | Experiments outside production |
| [`docs/`](docs/README.md) | Reference pages and runbooks |

## Security

Encrypt tracked secrets with SOPS and age. Keep private keys and dotenv files
out of git. This repository is public.

## Notes

LXC module patterns follow
[`trfore/terraform-bpg-proxmox`](https://github.com/trfore/terraform-bpg-proxmox),
which uses Apache-2.0.

## License

[MIT](LICENSE)
