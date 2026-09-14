# Changelog

This file records all notable changes to the project. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning starts
when the first release is cut.

## [Unreleased]

### Added

- Monorepo root skeleton: documentation, ignore policy, Task, mise, and SOPS
  placeholders, top-level architecture directories with purpose markers.
- Ansible shell: complete directory topology (inventory, playbooks,
  roles, collections, plugins), `ansible.cfg`, Python toolchain lock
  (`pyproject.toml` + `uv.lock`), lint configs, and a local verification
  contract (`task verify`) that needs no managed host.
- PVE onboarding pattern and `converge` playbook for Proxmox pets
  (first node: jarvis).
- Terraform state backend: a frozen OpenTofu bootstrap root for the OVH S3
  state bucket. The bucket carries versioning, SSE, a 90-day lifecycle, and
  an allowlist policy without `DeleteBucket` or `DeleteObjectVersion`.
  `terraform/BACKEND.md` is the design record, with an onboarding runbook
  and `task tf:*` recipes including offline schema validation.
- Packer golden images: versioned Debian 13 LXC artifacts built from the
  node's official container template. The build drives `pct` over SSH and
  stores a vzdump archive in the template cache. Images chain one on another,
  each pinning its parent, and the archive name carries the lineage. Each
  node has a local connection file, and container logs go to journald.
  Recipes are `task packer:*`, with the build runbook. The build contacts the
  node and needs owner approval.
- First PVE layer: the shared `terraform/proxmox/modules/lxc/` module wraps
  one LXC workload, cloning a golden image over DHCP and enabling Docker.
  The `terraform/proxmox/jarvis/` root holds one module call per workload
  through the bpg provider. State is remote and encrypted on the shared OVH
  bucket, with an S3 lockfile. The tree groups by provider category:
  `proxmox/` holds the PVE root and its shared modules, and `bootstrap/ovh/`
  holds the state backend root. Recipes are `task tf:jarvis-{plan,apply,
  output}`, with the provisioning runbook. Root credentials live in
  git-ignored `*.local.auto.tfvars` beside their root. The shared `.env.tf`
  carries native names (`TF_VAR_*`, `AWS_*`), and the OVH account file is
  `.env.account.ovh.tf`.
- OVH object storage conventions (`docs/object-storage.md`): one bucket
  per data class, one allowlisted user per bucket, client-side encryption
  for non-state payloads. `task ovh:s3-ls` lists the state bucket.
- PVE access bootstrap: the frozen `terraform/bootstrap/pve/jarvis/` root
  takes the whole Terraform access chain from Ansible. That chain is the
  role, the group, the user, and the ACL. The root mints the API token as
  code, with one-time import blocks, `prevent_destroy` everywhere, and a
  token-only user. Runbook `docs/runbooks/bootstrap-pve-access.md`, tasks
  `task tf:pve-jarvis-*`.
- Plan-time checks in the jarvis root. The storages its images and disks
  address must exist and be active, and the node must run PVE 8+. Every
  container tagged `terraform` on the node must belong to the root. A
  drifted or hand-made container fails the plan.
- Prose gate: `task docs:check` runs Vale with eleven rules, wired into
  `task verify`. Nine come vendored from the Google style guide, versioned
  with the repository, so the check stays offline. The rules cover the
  spaced em dash, contractions, semicolons, timeless wording, excessive
  claims, Latin abbreviations, American spelling, anthropomorphism, and
  unfamiliar acronyms. `Vale.Terms` adds the exact casing of every term in
  the project vocabulary, and `Std.Readability.SentenceLength` caps a
  sentence at 25 words. Every rule is raised to `error`, because Vale fails
  a run on an error alert only. The vocabulary lives under
  `.vale/styles/config/vocabularies/House/` and follows the Host terminology
  section of `AGENTS.md`. Nine of the rules also run over the comments in the
  tracked YAML, TOML, HCL, shell, and config files. `docs/writing.md` records
  the rules, the tooling, and the source behind each one.
- Link check: `task docs:links` runs lychee over the tracked Markdown, offline
  and anchors included, and rides in `task verify`. `task docs:links-external`
  checks the outbound links over the network.

### Changed

- The shared LXC module takes the full trfore surface. It covers static
  IPv4 with an optional gateway, the VLAN tag, a stable MAC, and swap. DHCP
  stays the default. It also covers the boot flag with its order and delays,
  mount points, and the PVE protection flag. A wait-for-IPv4 makes `ct_ipv4`
  fill in from the guest. A Docker image reports `docker0` too, so `ct_ipv4`
  reads the named interface and stays null until that one holds a lease.
  Patterns adapted from `trfore/terraform-bpg-proxmox`
  (Apache-2.0).
- Backend config split: the shared OVH S3 facts move to the tracked partial
  config `terraform/backend.s3.ovh.hcl`. Those facts are the region, the
  endpoint, the validation skips, and the lockfile. The tf tasks pass the
  file at init, and each root keeps only its `key`. No value changed, so no
  state moves.
- The Proxmox Ansible plane retracts the Terraform identity: role,
  group, user, and ACL leave `vars.yml`. The `terraform-prov` password
  leaves the SOPS file (token-only user now). `credential_check` tests
  the API token instead of a password ticket.
- `task ansible:verify` now runs the SOPS canary playbook: a broken
  SOPS structure fails the local check instead of surfacing at the
  next converge.
- State keys mirror the root path (`<path>/terraform.tfstate`) instead
  of chosen names, so the planned Terragrunt adoption needs no state
  migration. The `jarvis` state moved to
  `proxmox/jarvis/terraform.tfstate` (object copy). The state is empty.
- Documentation tree restructured around one Diátaxis type per file.
  `docs/README.md` is the index, and `docs/ssh.md` keeps the reference while
  the pinning procedure moves to `docs/runbooks/pin-host-keys.md`. The state
  backend runbook splits out `docs/runbooks/rotate-s3-credential.md` and
  `docs/ovh-least-privilege.md`. Every cross-reference is now a relative
  link, and the how-to pages end with next steps. The orphan
  `docs/bootstrap.md` stub is gone.
- House style drops the spaced em dash: 66 occurrences across 26 files now
  use a colon, parentheses, or a comma. The rule is in `AGENTS.md`.
- Prose uses contractions: 39 occurrences of `do not`, `is not`, and
  similar become `don't`, `isn't`. A verbatim error string keeps its
  long form, in backticks. The rule is in `AGENTS.md`.

### Security

- Each task declares its secrets: `.env.tf` carries the OpenTofu inputs
  and the state-backend `AWS_*` keys, and `.env.account.ovh.tf` carries
  the OVH account credential. Only the `tf:*` and `ovh:cli` tasks read
  them, so a third-party binary another task spawns inherits no secret.
  The age-key path comes from the committed `mise.toml`.
- SOPS + age baseline: encrypted group_vars, age keypairs (main + backup),
  creation rules, canary enforcement, `docs/sops.md` procedures.
