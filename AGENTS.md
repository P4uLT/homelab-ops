# AGENTS.md

Guidance for AI coding agents working in this repository.

## Overview

Public infrastructure-as-code monorepo for a homelab: Packer golden images,
Terraform on Proxmox VE, Ansible runtime configuration, and a Talos/Flux lab.
[mise](https://mise.jdx.dev) manages tools. [Task](https://taskfile.dev) runs tasks.

## Commands

```sh
task verify                                   # full local proof. No host contact.
task ansible:inventory -- --host jarvis       # resolved vars, decrypted in memory
task ansible:site                            # applies server config, may contact hosts
task sops:encrypt -- <path>                   # also: decrypt, edit, encrypt-all, check-all
task ansible:galaxy                           # vendor install if missing
task ansible:galaxy-reinstall                 # purge and reinstall. Needs network.
task tf:init                                  # initialize every OpenTofu root
task tf:bootstrap-plan                        # plan the state backend. Read-only.
task tf:bootstrap-apply -- -auto-approve      # create. Needs owner approval.
task tf:pve-jarvis-plan                       # plan the PVE access bootstrap. Read-only.
task tf:pve-jarvis-apply -- -auto-approve     # mint the token. Needs owner approval.
```

`task verify` is the required local check. Run it before you claim success.
On a fresh clone, run `mise install` before the first task: the pinned
toolchain, `task` included, comes from it.
In a shell without the mise hook, prefix commands with `mise exec --`.

## Task layout

- One component, one file: `.taskfiles/<component>.yml`, included from the
  root `Taskfile.yml`. The file name is the task prefix: `tf.yml` gives `tf:`.
- Put `dir:` on the include when every task in the component shares one
  working directory. Otherwise set `dir:` on each task.
- Prefer Task primitives over shell. Iterate with `for` over a variable,
  require values with `requires.vars`, and keep the shell inside the command
  itself. A shell loop wrapped around several tool calls is a design smell.

## Layout (ansible shell)

```text
ansible/
├── config/ansible.cfg      # settings. Symlinked at ansible/ for auto-discovery.
├── requirements.yml        # all vendor pins: roles and collections
├── inventory/servers/
│   ├── groups.yml          # group tree. No hosts here.
│   ├── hosts.yml           # host membership only
│   ├── iac.tf.yml          # Terraform-generated placeholder
│   └── group_vars/         # variables live HERE. See the gotcha below.
├── roles/vendors/          # galaxy-installed. Git-ignored. Never edit.
└── collections/vendors/    # same
```

## Hard rules

- Public repo. No cleartext IPs, credentials, or usernames. Hostnames and
  group names are fine.
- Secrets live only in `*.sops.yaml` files (SOPS + age). Encrypt with
  `task sops:encrypt`. Procedures: `docs/sops.md`.
- The canary variable loads on every inventory-based run. Without the age
  key, every run fails loudly. That's by design, not a bug.
- The age key file is local (`.age.key.txt`, git-ignored). The committed
  `mise.toml` sets `SOPS_AGE_KEY_FILE`.
- Each task declares its secrets: a task that needs one loads it with
  `dotenv`. Never put a secret in the environment every task inherits.
- Each secret lives where its consumer resolves it. Task resolves a
  dotenv path against the task's directory, and skips a missing file
  without a word. A task that loads one therefore carries a
  `preconditions` check. A root's connection secrets live in the root, as a git-ignored
  `*.local.auto.tfvars`. Packer keeps `<node>.local.pkrvars.hcl` in
  `packer/hosts/`.
- Name a secret file for the scope it opens, never for one of its
  consumers. The role comes first, a vendor only qualifies it.
- Two git-ignored dotenv files at the repository root, mode 600.
  `.env.tf` holds what every OpenTofu task needs, under the native names
  of its consumer. `.env.account.ovh.tf` holds the OVH account
  credential, read only by the bootstrap root and `ovh:cli`.
- Never edit `roles/vendors/` or `collections/vendors/` content. A patch
  means a fork pin in `requirements.yml` or a copy in `roles/local/`.
- Never enable `display_args_to_stdout` or `[diff] always`: task arguments
  and diffs can leak secret values into logs.
- Don't run `-vv` or `--diff` on secret-bearing plays.
- Check mode can change the node. Get owner approval before any host contact.
- A non-root node stores its `ansible_become_password` in the node group
  secrets file. Never a prompt setting in the config.

## Host terminology

Use the specific system name when you know it:

- Proxmox hypervisor: PVE host that runs VMs and LXC containers.
- NAS: storage host.
- Raspberry Pi: ARM host.
- Terraform-created LXC container: LXC workload created by Terraform.
- Terraform-created VM: VM workload created by Terraform.
- Talos node: Kubernetes host.
- Packer-built image: image source, not a host.

Use the provisioning source when it matters: Terraform, Packer, manual, or
bare metal. Use `host` only when the system type is unknown.

## Gotchas

- `group_vars` must sit beside the inventory source:
  `inventory/servers/group_vars/`. Ansible doesn't walk parent
  directories. Files at `ansible/group_vars/` never load.
- In a non-TTY harness, ansible refuses to run. Wrap the command in a
  pseudo-terminal: `script -qec '<command>' /dev/null`.
- Extra-vars with JSON die in `task ansible:converge --`: the quotes are
  stripped across the two shell layers and the value degrades to a string.
  Use the file form instead: `-e @/tmp/vars.yml`.
- `task verify` works offline after the first `galaxy` install, the
  first OpenTofu provider download (`task tf:init`), and the first Packer
  plugin download (`task packer:init`). Its OpenTofu leg also needs the
  state passphrase from `.env.tf`, or `tf:init` stops on the encrypted
  state. `galaxy-reinstall` needs network and wipes manual changes in
  `vendors/`.
- The golden LXC images ship without apt package lists. An apt task on a
  clone needs `update_cache: true` or `cache_valid_time`, or it fails with
  `Unable to locate package`.
- The OVH project API takes the region in UPPERCASE (`EU-WEST-PAR`). The S3
  endpoint takes it lowercase. Lowercase in the API returns
  `Invalid region parameter`.
- `tofu init -backend=false` can't read a local state that OpenTofu native
  encryption protects. It fails with `Unsupported state file format`, and
  `-reconfigure` and `-upgrade` don't help. Run `task tf:init` instead.
- The `encryption` block is OpenTofu-only, and a Terraform-schema linter
  rejects it. `.pi-lens.json` keeps the two backend files out of its
  scans. `tofu validate` and `tflint` are authoritative, and `task
  verify` runs both. `terraform/README.md` has the editor setup.
- The OpenTofu S3 backend speaks the AWS dialect. On the OVH endpoint it
  needs `skip_region_validation`, `skip_credentials_validation` (OVH has
  no STS), and a static `endpoints` value.
  `terraform/backend.s3.ovh.hcl` shows the set.
- The OVH S3 policy API drops actions it doesn't support, such as
  `s3:GetObjectVersion`. A dropped action shows a diff on every plan. Keep
  the policy to the minimal allowlist.
- A plan that waits for approval fails with `error asking for approval:
  EOF` without a terminal. Pass `-auto-approve` after `--`.
- Vale fails a run on an `error` alert only. A rule left at the
  `suggestion` or `warning` level it ships with reports findings and still
  exits 0, so `.vale.ini` raises every rule it enables to `error`.
- The legacy sibling repository that fed the migration keeps a read-only
  status. Never change it.
- Add at most one gotcha per PR, and only for a mistake it prevented or
  fixed.

## Style

- Rules, tooling, and sources: `docs/writing.md`. It wins on prose detail.
  The check is `task docs:check`.
- Tools: keep their own name, `packer` and `uv` included. `mise exec --` is
  a shell fallback, never written in a file.
- Docs: short sentences. Active voice. Plain words.
- Contractions: "don't", "isn't", "can't". A verbatim error string keeps
  its long form, in backticks.
- Comments: short. State the why, not the what. Delete a comment that
  restates the line under it.
- Prefer the documented standard over a local trick. When a choice isn't
  standard, record the reason next to it.
- Commits: `type(scope): summary`. Imperative. 72 characters max.
- PRs follow `.github/pull_request_template.md`.

## Pointers

- `docs/README.md`: the documentation index. Start here.
- `docs/writing.md`: the writing rules, the tooling, and each rule's source.
- `terraform/BACKEND.md`: Terraform state design and recovery.
- `.agents/skills/docs-sync`: the loop that resyncs the docs after a change.
