# terraform/

Infrastructure as code for Proxmox VE and TrueNAS, on OpenTofu.

- One Terraform root per PVE server: its own code, state, and token.
  The PVE resources use the [bpg provider](https://github.com/bpg/terraform-provider-proxmox).
  Planned. No PVE root exists yet.
- `truenas/` imports datasets, NFS shares, and snapshots. Everything that
  democratic-csi creates stays out of Terraform management.
  Planned. The directory does not exist yet.
- `talos-lab/` holds discovery VMs only. Production Talos nodes are
  bare metal and stay outside Terraform. Planned.
- `bootstrap/` is the frozen root that owns the state backend. It is the
  only root today, and the only one with a local state.

State lives in the OVH S3 backend, never in git. Read `BACKEND.md`
before the first stateful run.

## Root rules

One root covers one provider, one blast radius, and one apply cadence.
Do not split roots by resource type. `bootstrap/` stays frozen and owns
only the state backend. Every root declares its own state key in its
`backend.tf`. Never derive the key from the directory path. See
`BACKEND.md` for the full rules.

## Editor setup

These files are OpenTofu. The HashiCorp Terraform language server
rejects valid OpenTofu blocks such as `encryption` with
"Blocks of type ... are not expected here". Use the OpenTofu extension
([vscode-opentofu](https://marketplace.visualstudio.com/items?itemName=OpenTofu.vscode-opentofu))
version 0.6.3 or newer: older versions bundle a language server whose
schema does not know the `encryption` block and raises the same false
error. Linting runs through `task tf:lint` with the repository
`terraform/.tflint.hcl`.
