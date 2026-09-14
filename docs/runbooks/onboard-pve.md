# Add a Proxmox VE node

Keep addresses and credentials in SOPS-encrypted group variables. See
[SOPS and age procedures](../sops.md) for the encryption itself.

Three sections below contact the node: **Create the users**, **Storages**, and
**Golden images**. Get owner approval before you start them. Check mode can
change the node too.

## Inventory and secrets

Three steps put the node on paper before anything touches it.

1. Add the node leaf group to `ansible/inventory/servers/groups.yml`, then the
   hostname to `hosts.yml`.
2. Store `ansible_host` and `ansible_user` in the node group's
   `secrets.sops.yaml` file. A non-root node also stores its
   `ansible_become_password` there.
3. Store the shared PVE host-plane variables (the storages and the
   non-Terraform users) in
   `ansible/inventory/servers/group_vars/grp_servers_proxmox/secrets.sops.yaml`.

## SSH access

These two steps give you login and prove the host is the one you think it is.

1. Add the node to `~/.ssh/config`. Use `StrictHostKeyChecking accept-new` and
   the root SSH key. The block pattern is in
   [SSH key and host-key practices](../ssh.md).
2. Pin the node host key. See [Pin a host key](pin-host-keys.md):
   `task ansible:hostkey -- <node-ip>`, compare on the node console, then
   `task ansible:hostkey-pin -- <node-ip>`.

## Create the users

Four steps run the role and prove the credential it needs.

1. Run the local checks: `task verify`.
2. Preview the changes: `task ansible:converge-check`.
3. Create the non-Terraform users, without storages:

   ```sh
   echo 'pve_storages: []' > /tmp/skip-storages.yml
   task ansible:converge -- -e @/tmp/skip-storages.yml
   ```

   The file form survives the shell layers. An inline `-e "pve_storages=[]"`
   becomes the string `[]` and breaks the role.

   The Terraform access chain is not part of this run. It comes from the
   node's own frozen root under `terraform/bootstrap/pve/`, created by copying
   `terraform/bootstrap/pve/jarvis/`. See
   [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md).

4. Run the node's access root, then test the token it minted:
   `task ansible:playbook -- playbooks/oper/credential_check.yml`.

## Storages

The node serves container disks from the NAS, so the export has to exist first.

1. Apply the storage configuration: `task ansible:converge`. Before running
   it: create the NFS export `/export/Proxmox` on the NAS and allow the node
    IP. Check the `pve_storages` values in the shared group secrets
    (`task sops:decrypt -- ...`). After the run, check Datacenter → Storage in
    the PVE UI.

## Golden images

Build the images on the node before Terraform can clone one.

1. Build the golden images on the node: add the node to `PKR_HOSTS` in
   `.taskfiles/packer.yml`, create `packer/hosts/<node>.pkrvars.hcl` (node
   facts) and `packer/hosts/<node>.local.pkrvars.hcl` (connection,
   git-ignored), then run `task packer:build`. See
   [Build the golden images](build-base-image.md).

## Clean up

Review `ansible/config/tmp/ansible.log`, then delete it.

## Next steps

- [Provision an LXC workload with Terraform](provision-pve-ct.md) — the first
  container on the new node.
- [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md) —
  the access root you copied for this node.
- [SSH key and host-key practices](../ssh.md) — the key and inventory rules
  the node now follows.
