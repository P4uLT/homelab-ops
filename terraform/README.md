# terraform/

Infrastructure as code for Proxmox VE and TrueNAS, on OpenTofu.

The tree groups by provider category. A category holds one root per
target.

- `proxmox/` holds one root per PVE server, plus `proxmox/modules/` for
  what those roots share. The PVE resources use the
  [bpg provider](https://github.com/bpg/terraform-provider-proxmox).
  `proxmox/jarvis/` owns LXC workloads and optional imported-image VMs through
  separate maps in its git-ignored tfvars. An apply writes an Ansible inventory
  fragment for each LXC workload:
  `ansible/inventory/servers/iac.tf.<node>.yml`. Each LXC workload joins
  `grp_servers_immutable` through a `grp_servers_immutable_<host>` leaf. The leaf
  repeats its parent's name and replaces hyphens with underscores. The fragment
  includes the LXC hostname and container ID, but no address.
  A later PVE server gets its own root, named after it.
- `proxmox/modules/lxc/` wraps one LXC workload: a golden image clone,
  started, addressed by DHCP unless the caller pins a static address from its
  git-ignored tfvars. Node facts live in the calling root, in its `locals.tf`.
- `proxmox/modules/vm/` wraps one VM booted from an imported QCOW2 image.
  The Jarvis root owns server-side downloads and keeps VM workloads out of Linux Ansible.
  A declared download pin owns its source image. Removing a workload leaves the
  image. Removing the pin deletes it. Existing managed images enter state
  through conditional imports. `vm_image_files` reads existing files without
  taking ownership. Downloads use the API. VM disk imports use SSH with an
  agent key.
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
