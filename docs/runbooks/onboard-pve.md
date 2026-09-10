# Add a Proxmox VE node

Keep addresses and credentials in SOPS-encrypted group variables.

## Steps

1. Add the node leaf group to `ansible/inventory/servers/groups.yml`, then the hostname to `hosts.yml`.
2. Store `ansible_host` and `ansible_user` in the node group's `secrets.sops.yaml` file. A non-root
   node also stores its `ansible_become_password` there.
3. Store shared PVE variables under `ansible/inventory/servers/group_vars/grp_servers_proxmox/`.
4. Add the node to `~/.ssh/config`. Use `StrictHostKeyChecking accept-new` and the root SSH key.
5. Run the local checks: `task verify`.
6. Preview the changes: `task ansible:converge-check`.
7. Create users, groups, roles, and ACLs: `task ansible:converge -- -e "pve_storages=[]"`.
8. Test the new credentials:
   `task ansible:playbook -- playbooks/servers/stacks/proxmox/credential_check.yml`.

9. Apply the storage configuration: `task ansible:converge`.
10. Review and delete `ansible/config/tmp/ansible.log`.

Steps 6 through 9 contact the node. Get owner approval before steps 6, 7, and 9. Check mode can change the node.
