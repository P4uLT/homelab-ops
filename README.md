# homelab-ops

Infrastructure-as-code monorepo for the homelab: Packer golden images,
Terraform on Proxmox VE, Ansible runtime configuration, and a Talos/Flux
Kubernetes lab.

## Layout

| Path | Purpose |
| ---- | ------- |
| `packer/` | Golden LXC images, pinned by digest |
| `terraform/` | Proxmox infrastructure, one root per server |
| `ansible/` | Runtime configuration (hub-and-spoke playbooks) |
| `kubernetes/` | Talos + Flux bare-metal lab |
| `lab/` | Experiments, non-production |
| `docs/` | Bootstrap, SOPS, runbooks |

## Phases

[PROGRESS.md](PROGRESS.md) tracks the phases. The repo grows in phases:
root skeleton → Ansible shell → content import → Packer / Terraform →
Kubernetes.

## Usage

[Task](https://taskfile.dev) drives the tasks (`task --list`).
[mise](https://mise.jdx.dev) manages the toolchain (`mise.toml`).

## License

[MIT](LICENSE)
