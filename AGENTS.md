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
```

`task verify` is the required local check. Run it before you claim success.
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
  key, every run fails loudly. That is by design, not a bug.
- The age key file is local (`.age.key.txt`, git-ignored). The committed
  `mise.toml` sets `SOPS_AGE_KEY_FILE`.
- `.env` is git-ignored. It holds the OVH API credential, which can act on
  the whole account. Keep it at mode 600.
- Never edit `roles/vendors/` or `collections/vendors/` content. A patch
  means a fork pin in `requirements.yml` or a copy in `roles/local/`.
- Never enable `display_args_to_stdout` or `[diff] always`: task arguments
  and diffs can leak secret values into logs.
- Do not run `-vv` or `--diff` on secret-bearing plays.
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
  `inventory/servers/group_vars/`. Ansible does not walk parent
  directories. Files at `ansible/group_vars/` never load.
- In a non-TTY harness, ansible refuses to run. Wrap the command in a
  pseudo-terminal: `script -qec '<command>' /dev/null`.
- Extra-vars with JSON die in `task ansible:converge --`: the quotes are
  stripped across the two shell layers and the value degrades to a string.
  Use the file form instead: `-e @/tmp/vars.yml`.
- `task verify` works offline after the first `galaxy` install and the
  first OpenTofu provider download (`task tf:init`). `galaxy-reinstall`
  needs network and wipes manual changes in `vendors/`.
- The OVH project API takes the region in UPPERCASE (`EU-WEST-PAR`). The S3
  endpoint takes it lowercase. Lowercase in the API returns
  `Invalid region parameter`.
- `tofu init -backend=false` cannot read a local state that OpenTofu native
  encryption protects. It fails with `Unsupported state file format`, and
  `-reconfigure` and `-upgrade` do not help. Run `task tf:init` instead.
- The OVH S3 policy API drops actions it does not support, such as
  `s3:GetObjectVersion`. A dropped action shows a diff on every plan. Keep
  the policy to the minimal allowlist.
- A plan that waits for approval fails with `error asking for approval:
  EOF` without a terminal. Pass `-auto-approve` after `--`.
- The legacy sibling repository that fed the migration keeps a read-only
  status. Never change it.

## Style

- Docs: short sentences. Active voice. Plain words.
- Comments: short. State the why, not the what. Delete a comment that
  restates the line under it.
- Commits: `type(scope): summary`. Imperative. 72 characters max.
- PRs follow `.github/pull_request_template.md`. Update `CHANGELOG.md` when
  user-visible behavior changes.

## Pointers

- `docs/sops.md` — encrypt, decrypt, backup key, fresh-clone recovery.
- `docs/ssh.md` — keys, host-key pinning, access inventory.
- `docs/runbooks/onboard-pve.md` — add a Proxmox VE node.
- `docs/runbooks/bootstrap-tf-backend.md` — one-time state backend setup.
- `terraform/BACKEND.md` — Terraform state design and recovery.
- `CHANGELOG.md` — notable changes.
