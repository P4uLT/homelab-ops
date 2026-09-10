# Runbook — onboard a Proxmox VE node

This runbook adds one PVE node to the managed fleet. It follows the pattern
that jarvis established (phase 1a). It contains no IP and no credential:
network locators and credentials live in SOPS-encrypted group_vars.

## Steps

1. Add the node group and hostname to `ansible/inventory/servers/static.yml`
   under `grp_servers_proxmox`, one group per node.
2. Create `ansible/inventory/servers/group_vars/grp_servers_proxmox_<node>/secrets.sops.yaml`
   with `ansible_host` and `ansible_user`. Encrypt it (`docs/sops.md`).
3. Share fleet-level users, groups, roles, ACLs, and storages through
   `ansible/inventory/servers/group_vars/grp_servers_proxmox/` (vars.yml or secrets.sops.yaml).
4. Prepare SSH outside the repository: `~/.ssh/config` entry with
   `StrictHostKeyChecking accept-new` and the key for the node's root account.
5. Local proof: `task -d ansible verify`, then the canary playbook.
6. Owner approval, then `task -d ansible converge-check` (best-effort preview).
7. Owner approval, then `task -d ansible converge -- -e "pve_storages=[]"`
   (identity plane). Test new credentials with
   `playbooks/oper/proxmox_credential_check.yml`.
8. Owner approval, then `task -d ansible converge` (full convergence).
9. Review and delete `ansible/config/tmp/ansible.log`.

## Verification gates

Gates 2, 3a, and 3b each require explicit owner approval. Check mode is a
best-effort preview, not a guaranteed read-only mode.
