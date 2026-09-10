# AGENTS.md

Guidance for AI coding agents working in this repository.

## Overview

Public infrastructure-as-code monorepo for a homelab: Packer golden images,
Terraform on Proxmox VE, Ansible runtime configuration, and a Talos/Flux lab.
The repo grows in phases. See `PROGRESS.md` for the current phase.
[mise](https://mise.jdx.dev) manages tools. [Task](https://taskfile.dev) runs tasks.

## Commands

```sh
task verify                                   # full local proof. No host contact.
task ansible:inventory -- --host jarvis       # resolved vars, decrypted in memory
task sops:encrypt -- <path>                   # also: decrypt, edit, encrypt-all, check-all
task ansible:galaxy                           # vendor install if missing
task ansible:galaxy-reinstall                 # purge and reinstall. Needs network.
```

`task verify` is the single gate for every change. Run it before you claim success.
Tools come from mise. In a shell without the mise hook, prefix with `mise exec --`.

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
  `mise.toml` sets `SOPS_AGE_KEY_FILE`. You do not need a `.env` file.
- Never edit `roles/vendors/` or `collections/vendors/` content. A patch
  means a fork pin in `requirements.yml` or a copy in `roles/local/`.
- Never enable `display_args_to_stdout` or `[diff] always`: task arguments
  and diffs can leak secret values into logs.
- Do not run `-vv` or `--diff` on secret-bearing plays.
- Check mode can change the node. Owner approval gates every host contact.
- A non-root node stores its `ansible_become_password` in the node group
  secrets file. Never a prompt setting in the config.

## Gotchas

- `group_vars` must sit beside the inventory source:
  `inventory/servers/group_vars/`. Ansible does not walk parent
  directories. Files at `ansible/group_vars/` never load.
- In a non-TTY harness, ansible refuses to run. Wrap the command in a
  pseudo-terminal: `script -qec '<command>' /dev/null`.
- `task verify` works offline after the first `galaxy` install.
  `galaxy-reinstall` needs network and wipes manual changes in `vendors/`.
- The legacy sibling repository that fed the migration is read-only.
  Never change it.

## Style

- Docs: short sentences. Active voice. Plain words.
- Commits: `type(scope): summary`. Imperative. 72 characters max.
- PRs follow `.github/pull_request_template.md`. Update `CHANGELOG.md` and
  `PROGRESS.md` when phase state moves.

## Pointers

- `docs/sops.md` — encrypt, decrypt, backup key, fresh-clone recovery.
- `docs/runbooks/onboard-pve.md` — add a Proxmox VE node.
- `PROGRESS.md` — phase index. `CHANGELOG.md` — notable changes.
