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

### Changed

- The shared LXC module takes the full trfore surface: static IPv4 with
  optional gateway (DHCP stays the default), VLAN tag, stable MAC,
  swap, boot flag with order and delays, mount points, PVE protection
  flag, and a wait-for-IPv4 so `ct_ipv4` is usable at the end of an
  apply. Patterns adapted from `trfore/terraform-bpg-proxmox`
  (Apache-2.0).

### Security

- Secrets are declared per task: `.env.tf` carries the OpenTofu inputs
  and the state-backend `AWS_*` keys, and `.env.account.ovh.tf` carries
  the OVH account credential. Only the `tf:*` and `ovh:cli` tasks read
  them, so a third-party binary another task spawns inherits no secret.
  The age-key path comes from the committed `mise.toml`.
- SOPS + age baseline: encrypted group_vars, age keypairs (main + backup),
  creation rules, canary enforcement, `docs/sops.md` procedures.
