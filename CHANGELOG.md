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

### Security

- SOPS + age baseline: encrypted group_vars, age keypairs (main + backup),
  creation rules, canary enforcement, `docs/sops.md` procedures.
