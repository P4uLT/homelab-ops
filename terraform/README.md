# terraform/

Infrastructure as code for Proxmox VE and TrueNAS, on OpenTofu.

- One Terraform root per PVE server: its own code, state, and token.
  The PVE resources use the [bpg provider](https://github.com/bpg/terraform-provider-proxmox).
- `truenas/` imports datasets, NFS shares, and snapshots. Everything that
  democratic-csi creates stays out of Terraform management.
- `talos-lab/` holds discovery VMs only. Production Talos nodes are
  bare metal and stay outside Terraform.
- `bootstrap/` is the frozen root that owns the state backend. It is the
  only root with a local state.

State lives in the OVH S3 backend, never in git. Read `BACKEND.md`
before the first stateful run.

## Editor setup

These files are OpenTofu. The HashiCorp Terraform language server
rejects valid OpenTofu blocks such as `encryption` with
"Blocks of type ... are not expected here". Use the OpenTofu language
server (`tofu-ls`, or the OpenTofu extension in your editor) instead.
Linting runs through `task tf:lint` with the repository `.tflint.hcl`.
