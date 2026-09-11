# Add a Proxmox VE node

Keep addresses and credentials in SOPS-encrypted group variables.

## Steps

1. Add the node leaf group to `ansible/inventory/servers/groups.yml`, then the hostname to `hosts.yml`.
2. Store `ansible_host` and `ansible_user` in the node group's `secrets.sops.yaml` file. A non-root
   node also stores its `ansible_become_password` there.
3. Store shared PVE variables under `ansible/inventory/servers/group_vars/grp_servers_proxmox/`.
4. Add the node to `~/.ssh/config`. Use `StrictHostKeyChecking accept-new` and the root SSH key.
5. Pin the node host key. See `docs/ssh.md`.
   `task ansible:hostkey -- <node-ip>`, compare on the node console, then
   `task ansible:hostkey-pin -- <node-ip>`.

6. Run the local checks: `task verify`.
7. Preview the changes: `task ansible:converge-check`.
8. Create users, groups, roles, and ACLs, without storages:

   ```sh
   echo 'pve_storages: []' > /tmp/skip-storages.yml
   task ansible:converge -- -e @/tmp/skip-storages.yml
   ```

   The file form survives the shell layers. An inline `-e "pve_storages=[]"`
   becomes the string `[]` and breaks the role.
9. Test the new credentials:
   `task ansible:playbook -- playbooks/oper/credential_check.yml`.
10. Apply the storage configuration: `task ansible:converge`.
    Before running it: create the NFS export `/export/Proxmox` on the NAS
    and allow the node IP. Check the `pve_storages` values in the shared
    group secrets (`task sops:decrypt -- ...`). After the run, check
    Datacenter → Storage in the PVE UI.
11. Review and delete `ansible/config/tmp/ansible.log`.

Steps 7 through 10 contact the node. Get owner approval before steps 7, 8, and 10. Check mode can change the node.
