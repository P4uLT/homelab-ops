# terraform/

Infrastructure as code for Proxmox VE and TrueNAS, on OpenTofu.

The tree groups by provider category. A category holds one root per
target.

- `proxmox/` holds one root per PVE server, plus `proxmox/modules/` for
  what those roots share. The PVE resources use the
  [bpg provider](https://github.com/bpg/terraform-provider-proxmox).
  `proxmox/jarvis/` is live: one `lxc_workloads` entry per LXC workload and
  independent VM image pins in `vm_image_downloads`, in its git-ignored
  tfvars. PVE downloads missing images through its API. OpenTofu imports
  matching filenames into state and deletes the image when you remove its pin.
  See the [Jarvis tfvars example](proxmox/jarvis/jarvis.local.auto.tfvars.example).
  An apply also writes the Ansible inventory fragment
  that makes each LXC workload a fleet host:
  `ansible/inventory/servers/iac.tf.<node>.yml`. Each LXC workload joins
  `grp_servers_immutable` through a `grp_servers_immutable_<host>` leaf. The leaf
  repeats its parent's name and
  replaces hyphens with underscores. The fragment includes the host and its
  container ID, but no address.
  A later PVE server gets its own root, named after it.
- `proxmox/modules/lxc/` wraps one LXC workload: a golden image clone,
  started, addressed by DHCP unless the caller pins a static address from its
  git-ignored tfvars. Node facts live in the calling root, in
  its `locals.tf`.
- `proxmox/modules/vm/` defines one VM that boots from an imported QCOW2 image.
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
root stores at `proxmox/jarvis/terraform.tfstate`.
Moving a root directory doesn't move its remote state.
Keep the existing backend key during a code move, or review a separate state migration.
See [State locations and code moves](BACKEND.md#state-locations-and-code-moves) for the rules.

## Local tests

Run `task tf:test` for the LXC and VM module tests.
The task uses OpenTofu mock providers, without root connection variables or host contact.
Provider installation can require registry access.
`task verify` includes these tests.
Generated module lock files stay local. Root lock files remain tracked.

## Editor setup

These files are OpenTofu. The HashiCorp Terraform language server
rejects valid OpenTofu blocks such as `encryption` with
`Blocks of type ... are not expected here`. Use the OpenTofu extension
([vscode-opentofu](https://marketplace.visualstudio.com/items?itemName=OpenTofu.vscode-opentofu))
version 0.6.3 or newer. Older versions bundle a language server whose
schema doesn't know the `encryption` block, and raises the same false
error. Linting runs through `task tf:lint` with the repository
`terraform/.tflint.hcl`.
