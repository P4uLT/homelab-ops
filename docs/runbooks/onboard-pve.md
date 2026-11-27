# Add a Proxmox VE node

Keep addresses and credentials in SOPS-encrypted group variables. See
[SOPS and age procedures](../sops.md) for the encryption itself.

Get owner approval before host contact, including SSH scans, convergence,
onboarding, storage changes, and builds. Check mode can also change the node.

## Inventory and secrets

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

1. Add the node to `~/.ssh/config`. Use `StrictHostKeyChecking accept-new` and
   the automation key. The block pattern is in
   [SSH key and host-key practices](../ssh.md). The key must be reachable by
   SSH: loaded in the agent, or named by an `IdentityFile` for the node's
   address.
2. Pin the node host key. See [Pin a host key](pin-host-keys.md):
   `task ansible:hostkey -- <node-ip>`, compare on the node console, then
   `task ansible:hostkey-pin -- <node-ip>`.

## Create the users

1. Run the local checks: `task verify`.
2. Preview the changes: `task ansible:converge-check HOST=<node>`. Set
   `HOST=grp_servers_proxmox` only when you intend to target every PVE node.
3. Create the non-Terraform users, without storages:

   ```sh
   echo 'pve_storages: []' > /tmp/skip-storages.yml
   task ansible:converge HOST=<node> -- -e @/tmp/skip-storages.yml
   ```

   Use the file form. The shell layers turn inline `-e "pve_storages=[]"` into
   the string `[]`, which breaks the role.

   The Terraform access chain isn't part of this run. It comes from the
   node's own frozen root under `terraform/bootstrap/pve/`, created by copying
   `terraform/bootstrap/pve/jarvis/`. See
   [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md).

4. Prove the Terraform token by planning the node's workload root. Jarvis uses
   `task tf:proxmox-jarvis-plan`. Add a matching task for each new root.

## Onboard the machine

Onboarding creates the fleet account using the node's initial login identity.
It verifies access and privilege escalation before disabling password login.
This is separate from the node-specific users created above and requires owner approval.

1. Check the console. A node needs the PVE console or a management card,
   reachable and tested: the run ends by closing password login.
2. Configure key-based image-build access before disabling password login.
   Set `pve_ssh_key_path` in `packer/hosts/<node>.local.pkrvars.hcl`.
   Load the key for `root` access to the PVE node.
3. Onboard with the initial login identity:

   ```sh
   task ansible:onboard HOST=<node> IDENTITY=root
   ```

   The run disables password login only after the account and escalation checks pass.
4. Check the fleet account:

   ```sh
   task ansible:playbook -- playbooks/servers/system/users.yml -l <node>
   ```

   Expect `changed=0`, which says the account was already complete.

Onboarding doesn't store the initial identity.
`ansible_user` in `ansible/inventory/servers/group_vars/all/vars.yml` remains
the fleet account. Root key access remains available for cluster operations.

## Storages

1. Create the NAS NFS export `/export/Proxmox` and allow the node IP.
2. Check `pve_storages` in the shared group secrets (`task sops:decrypt -- ...`).
3. With owner approval, apply `task ansible:converge HOST=<node>`.
4. Check Datacenter → Storage in the PVE UI.

## Golden images

Jarvis is the only configured Packer node.
Adding another node needs approved public and private node files.

1. Keep public storage and bridge facts in `packer/hosts/<node>.pkrvars.hcl`.
2. Keep private connection inputs in `<node>.local.pkrvars.hcl`, mode 600.
3. Pin the exact parent basename in the selected recipe.
   Base uses a vendor parent. Docker uses a qualified base archive.
4. With owner approval, run
   `task packer:build RECIPE=debian-13/lxc/base HOST=<node>`.
   Use `task packer:build-all HOST=<node>` only for the approved development scope.
5. Qualify the archive before Terraform selects it. Retain the qualified archive. See
   [Build and qualify the golden images](build-base-image.md).

## Remove reviewed logs

Review `ansible/config/tmp/ansible.log`. Delete the reviewed log.

## Next steps

- [Provision an LXC workload with Terraform](provision-pve-ct.md): the first
  container on the new node.
- [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md):
  the access root you copied for this node.
- [SSH key and host-key practices](../ssh.md): the key and inventory rules
  the node now follows.
