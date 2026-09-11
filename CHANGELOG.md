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
- TF-0 state backend scaffold: frozen OpenTofu bootstrap root for the
  OVH S3 state bucket and a cross-region replica (versioning, SSE,
  90-day lifecycle on both, allowlist policy without `DeleteBucket` or
  `DeleteObjectVersion`, replication with delete markers disabled),
  `terraform/BACKEND.md` design record, onboarding runbook, and
  `task tf:*` recipes including offline schema validation.

### Security

- SOPS + age baseline: encrypted group_vars, age keypairs (main + backup),
  creation rules, canary enforcement, `docs/sops.md` procedures.
