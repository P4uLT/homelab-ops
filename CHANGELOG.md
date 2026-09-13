# Changelog

This file records all notable changes to the project. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning starts
when the first release is cut.

## [Unreleased]

### Added

- Monorepo root skeleton: documentation, ignore policy, task/mise/sops
  placeholders, top-level architecture directories with purpose markers.
- Ansible shell: complete directory topology (inventory, playbooks,
  roles, collections, plugins), `ansible.cfg`, Python toolchain lock
  (`pyproject.toml` + `uv.lock`), lint configs, and a local verification
  contract (`task verify`) that needs no managed host.
- PVE onboarding pattern and `converge` playbook for Proxmox pets
  (first node: jarvis).
- Terraform state backend: frozen OpenTofu bootstrap root for the OVH S3
  state bucket (versioning, SSE, 90-day lifecycle, allowlist policy without
  `DeleteBucket` or `DeleteObjectVersion`), `terraform/BACKEND.md` design
  record, onboarding runbook, and `task tf:*` recipes including offline
  schema validation.
- Packer golden images: versioned Debian 13 LXC artifacts built from the
  node's official container template (SSH-driven `pct`, vzdump archive in
  the template cache, images chained one on another with a pinned parent
  and a name carrying the lineage, per-node local connection file, journald
  container logs), `task packer:*` recipes, and the build runbook. The
  build contacts the node and needs owner approval.
- First PVE layer: the shared `terraform/proxmox/modules/lxc/` module
  wraps one LXC workload (golden image clone, DHCP, Docker-ready
  features), and the `terraform/proxmox/jarvis/` root holds one module
  call per workload through the bpg provider. Encrypted remote state on
  the shared OVH bucket with an S3 lockfile. The tree groups by provider
  category: `proxmox/` holds the PVE root and its shared modules, and
  `bootstrap/ovh/` holds the state backend root. `task tf:jarvis-{plan,apply,
  output}` recipes, and the provisioning runbook. Root credentials live
  in git-ignored `*.local.auto.tfvars` beside their root. The shared
  `.env.tf` carries native names (`TF_VAR_*`, `AWS_*`), and the OVH
  account file is `.env.account.ovh.tf`.
- OVH object storage conventions (`docs/object-storage.md`): one bucket
  per data class, one allowlisted user per bucket, client-side encryption
  for non-state payloads. `task ovh:s3-ls` lists the state bucket.
- PVE access bootstrap: the frozen `terraform/bootstrap/pve/jarvis/`
  root takes the whole Terraform access chain from Ansible (role,
  group, user, ACL) and mints the API token as code: one-time import
  blocks, `prevent_destroy` everywhere, token-only user. Runbook
  `docs/runbooks/bootstrap-pve-access.md`, tasks `task tf:pve-jarvis-*`.
- Plan-time checks in the jarvis root: the storages its images and
  disks address must exist and be active, the node must run PVE 8+,
  and every container tagged `terraform` on the node must belong to
  the root — a drifted or hand-made container fails the plan.

### Changed

- The shared LXC module takes the full trfore surface: static IPv4 with
  optional gateway (DHCP stays the default), VLAN tag, stable MAC,
  swap, boot flag with order and delays, mount points, PVE protection
  flag, and a wait-for-IPv4 so `ct_ipv4` fills in from the guest. A
  Docker image reports `docker0` too, so `ct_ipv4` reads the named
  interface and stays null until that one holds a lease. Patterns
  adapted from `trfore/terraform-bpg-proxmox`
  (Apache-2.0).
- Backend config split: the shared OVH S3 facts (region, endpoint,
  validation skips, lockfile) move to the tracked partial config
  `terraform/backend.s3.ovh.hcl` that the tf tasks pass at init. Each
  root keeps only its `key`. Values are unchanged, so no state moves.
- The Proxmox Ansible plane retracts the Terraform identity: role,
  group, user, and ACL leave `vars.yml`; the `terraform-prov` password
  leaves the SOPS file (token-only user now); and `credential_check`
  tests the API token instead of a password ticket.
- `task ansible:verify` now runs the SOPS canary playbook: a broken
  SOPS structure fails the local check instead of surfacing at the
  next converge.
- State keys mirror the root path (`<path>/terraform.tfstate`) instead
  of chosen names, so the planned Terragrunt adoption needs no state
  migration. The `jarvis` state moved to
  `proxmox/jarvis/terraform.tfstate` (object copy; the state is empty).
- The Proxmox Ansible plane retracts the Terraform identity: role,
  group, user, and ACL leave `vars.yml`; the `terraform-prov` password
  leaves the SOPS file (token-only user now); and `credential_check`
  tests the API token instead of a password ticket.

### Security

- Secrets are declared per task: `.env.tf` carries the OpenTofu inputs
  and the state-backend `AWS_*` keys, and `.env.account.ovh.tf` carries
  the OVH account credential. Only the `tf:*` and `ovh:cli` tasks read
  them, so a third-party binary another task spawns inherits no secret.
  The age-key path comes from the committed `mise.toml`.
- SOPS + age baseline: encrypted group_vars, age keypairs (main + backup),
  creation rules, canary enforcement, `docs/sops.md` procedures.
