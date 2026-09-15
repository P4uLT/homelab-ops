# terraform/

Infrastructure as code for Proxmox VE and TrueNAS, on OpenTofu.

The tree groups by provider category. A category holds one root per
target.

- `proxmox/` holds one root per PVE server, plus `proxmox/modules/` for
  what those roots share. The PVE resources use the
  [bpg provider](https://github.com/bpg/terraform-provider-proxmox).
  `proxmox/jarvis/` is live: one `lxc_workloads` entry per LXC workload, in its
  git-ignored tfvars. An apply also writes the Ansible inventory fragment
  that makes each workload a fleet host:
  `ansible/inventory/servers/iac.tf.<node>.yml`.
  A later PVE server gets its own root, named after it.
- `proxmox/modules/lxc/` wraps one LXC workload: a golden image clone,
  started, addressed by DHCP unless the caller pins a static address from its
  git-ignored tfvars. Node facts live in the calling root, in
  its `locals.tf`.
- `truenas/` imports datasets, NFS shares, and snapshots. Everything that
  democratic-csi creates stays out of Terraform management.
  Planned. The directory doesn't exist yet.
- `talos-lab/` holds discovery VMs only. Production Talos nodes are
  bare metal and stay outside Terraform. Planned.
- `bootstrap/` mints credentials and stays frozen. `bootstrap/ovh/` owns the
  state backend, and is the only root with a local state. `bootstrap/pve/<node>/`
  owns one PVE node's Terraform access chain.

State lives in the OVH S3 backend, never in git. Read `BACKEND.md`
before the first stateful run.

## Root rules

One root covers one provider, one blast radius, and one apply cadence.
Don't split roots by resource type. `bootstrap/ovh/` stays frozen and owns
only the state backend. Every root declares its own state key in its
`backend.tf`, mirroring its path under `terraform/`: the `proxmox/jarvis`
root stores at `proxmox/jarvis/terraform.tfstate`. That's the layout Terragrunt
generates, so adopting Terragrunt needs no migration, and a root moved with
`git mv` moves its state with it. See `BACKEND.md` for the full rules.

## Editor setup

These files are OpenTofu. The HashiCorp Terraform language server
rejects valid OpenTofu blocks such as `encryption` with
`Blocks of type ... are not expected here`. Use the OpenTofu extension
([vscode-opentofu](https://marketplace.visualstudio.com/items?itemName=OpenTofu.vscode-opentofu))
version 0.6.3 or newer. Older versions bundle a language server whose
schema doesn't know the `encryption` block, and raises the same false
error. Linting runs through `task tf:lint` with the repository
`terraform/.tflint.hcl`.
