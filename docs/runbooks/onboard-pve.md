# Add a Proxmox VE node

Keep addresses and credentials in SOPS-encrypted group variables. See
[SOPS and age procedures](../sops.md) for the encryption itself.

Four sections below contact the node: **Create the users**, **Onboard the
machine**, **Storages**, and **Golden images**. Get owner approval before you
start them. Check mode can change the node too.

## Inventory and secrets

Three steps put the node on paper before anything touches it.

1. Add `grp_servers_proxmox_<node>` to
   `ansible/inventory/servers/groups.yml`, then add the hostname to
   `hosts.yml`.
2. Store `ansible_host` and `ansible_user` in the node group's
   `secrets.sops.yaml` file. A non-root node also stores its
   `ansible_become_password` there.
3. Store the shared PVE host-plane variables (the storages and the
   non-Terraform users) in
   `ansible/inventory/servers/group_vars/grp_servers_proxmox/secrets.sops.yaml`.

## SSH access

These two steps give you login and prove the host is the one you expect.

1. Add the node to `~/.ssh/config`. Use `StrictHostKeyChecking accept-new` and
   the automation key. The block pattern is in
   [SSH key and host-key practices](../ssh.md). The key must be reachable by
   SSH: loaded in the agent, or named by an `IdentityFile` for the node's
   address.
2. Pin the node host key. See [Pin a host key](pin-host-keys.md):
   `task ansible:hostkey -- <node-ip>`, compare on the node console, then
   `task ansible:hostkey-pin -- <node-ip>`.

## Create the users

Four steps run the role and prove the credential it needs.

1. Run the local checks: `task verify`.
2. Preview the changes: `task ansible:converge-check HOST=<node>`. Set
   `HOST=grp_servers_proxmox` only when you intend to target every PVE node.
3. Create the non-Terraform users, without storages:

   ```sh
   echo 'pve_storages: []' > /tmp/skip-storages.yml
   task ansible:converge HOST=<node> -- -e @/tmp/skip-storages.yml
   ```

   The file form survives the shell layers. An inline `-e "pve_storages=[]"`
   becomes the string `[]` and breaks the role.

   The Terraform access chain isn't part of this run. It comes from the
   node's own frozen root under `terraform/bootstrap/pve/`, created by copying
   `terraform/bootstrap/pve/jarvis/`. See
   [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md).

4. Prove the Terraform token by planning the node's workload root. Jarvis uses
   `task tf:jarvis-plan`. Add a matching task for each new root.

## Onboard the machine

The node's own users aren't the fleet account. Onboarding gives the machine the
account the whole fleet reaches it with, using the identity the node still
ships. It proves that account, then closes password login.

This contacts the node and closes a login. Get owner approval first.

1. Check the console. A node needs the PVE console or a management card,
   reachable and tested: the run ends by closing password login.
2. For a PVE node, give the image build a key. It reaches the node as `root`
   with a password, so closing password login breaks it. Set `pve_ssh_key_path`
   in `packer/hosts/<node>.local.pkrvars.hcl` and load that key.
3. Onboard it, passing the identity the node answers to today:

   ```sh
   task ansible:onboard HOST=<node> IDENTITY=root
   ```

   The run creates the account, proves it answers and escalates, then closes
   password login. Each phase gates the next, so a broken key stops the run
   before anything is closed.
4. Confirm the fleet's own contract holds:

   ```sh
   task ansible:playbook -- playbooks/servers/system/users.yml -l <node>
   ```

   Expect `changed=0`, which says the account was already complete.

The identity passed at onboarding is stored nowhere. `ansible_user` in
`ansible/inventory/servers/group_vars/all/vars.yml` names the fleet account
before the run, during it, and after it. Root keeps working by key, and a
cluster needs that: the play's header says why.

## Storages

The node serves container disks from the NAS, so the export has to exist first.

1. Apply the storage configuration: `task ansible:converge HOST=<node>`. Before running
   it: create the NFS export `/export/Proxmox` on the NAS and allow the node
    IP. Check the `pve_storages` values in the shared group secrets
    (`task sops:decrypt -- ...`). After the run, check Datacenter → Storage in
    the PVE UI.

## Golden images

Jarvis is the only configured Packer node.
Adding another node needs approved public and private node files.

1. Keep public storage and bridge facts in `packer/hosts/<node>.pkrvars.hcl`.
2. Keep private connection inputs in `<node>.local.pkrvars.hcl`, mode 600.
3. Pin the exact parent basename in the selected recipe.
   Base uses a vendor parent. Docker uses a qualified base archive.
4. Get owner approval, then run
   `task packer:build RECIPE=debian-13/lxc/base HOST=<node>`.
   Use `task packer:build-all HOST=<node>` only for the approved development scope.
5. Qualify and retain the archive before Terraform selects it. See
   [Build and qualify the golden images](build-base-image.md).

## Clean up

Review `ansible/config/tmp/ansible.log`, then delete it.

## Next steps

- [Provision an LXC workload with Terraform](provision-pve-ct.md): the first
  container on the new node.
- [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md):
  the access root you copied for this node.
- [SSH key and host-key practices](../ssh.md): the key and inventory rules
  the node now follows.
