# Provision an LXC workload with Terraform

`terraform/proxmox/jarvis/` creates LXC containers from Packer images on jarvis,
using the shared `terraform/proxmox/modules/lxc/` module.
Define workloads in the git-ignored tfvars `lxc_workloads` map.
`locals.tf` defines the node, storages, and bridge.
Each PVE server has a separate root and encrypted OVH S3 state.
See [Terraform state design](../../terraform/BACKEND.md).

Prerequisites:

- The golden images are in the node template storage. Build them first:
  [Build the golden images](build-base-image.md).
- `.env.tf` holds `TF_VAR_state_passphrase`, the `AWS_*` state backend keys,
  and `TF_VAR_bucket_name`.
- Owner approval before each plan or apply. Plans read the node, and applies change it.

## PVE API access

Create the role, group, `terraform-prov@pve` user, ACL, and API token through
`terraform/bootstrap/pve/jarvis/`. Follow [Bootstrap PVE access](bootstrap-pve-access.md).
Copy its `token_value` output. The provider uses the HTTPS API.

Then create `terraform/proxmox/jarvis/jarvis.local.auto.tfvars` from
`jarvis.local.auto.tfvars.example`, mode 600:

- `pve_endpoint`: the node address on your LAN, port 8006.
- `pve_api_token`: the full token value, `terraform-prov@pve!tf=<secret>`.

The root sets `insecure = true` for PVE's self-signed certificate.

## Apply the first container

Get owner approval before either command:

```sh
task tf:proxmox-jarvis-plan
task tf:proxmox-jarvis-apply -- -auto-approve
```

Expect one container to add. The apply clones the configured `template`,
starts it, and saves state to the bucket. This example uses the Docker image.
Check locking and image initialization:

- The apply takes the state lock with `use_lockfile`. OVH S3 supports conditional writes.
  If lock acquisition stalls, check for an active writer or a stale lock.
  Don't disable locking to bypass the failure. Get owner approval before clearing a confirmed stale lock.
- `image_finalize` requires an empty `/etc/machine-id` and no SSH host keys or
  apt lists in the sealed archive. At first boot, verify fresh machine IDs
  and host keys through [image qualification](build-base-image.md#6-qualify-the-candidate-archive).

## Check the container

Read `lxcs` in a private terminal. It contains sensitive addresses.
Plan and apply mask this output, as does unnamed output after sensitivity
metadata is saved. Network attributes in resource diffs aren't masked.
Named output, `-json`, and `-raw` can print plaintext. Keep them out of shared
logs and tracked files.

```sh
task tf:proxmox-jarvis-output -- -json lxcs
```

Each workload entry provides `ct_id` and `ct_ipv4`.
On the node, check Docker and image metadata. Pulling `hello-world` requires
outbound HTTPS from the container:

```sh
pct exec <ct_id> -- docker run --rm hello-world
pct exec <ct_id> -- cat /etc/image-build-info
```

The marker records the image name, version, and parent.
Review it explicitly because Ansible's preflight checks only file type, without
checking contents or provenance.

## The container joins the fleet

The image includes the fleet account for SSH access.
Add new device keys to both inventories with `task sops:edit`, then rebuild
the image chain. Builders supply image keys, while servers supply manually
provisioned hosts. Previously built archives still trust their original keys.

The root generates `ansible/inventory/servers/iac.tf.<node>.yml` with the group,
hostname, and container ID, without an address. Commit this cleartext fragment.
For `tf-test`, the leaf is `grp_servers_immutable_tf_test` under
`grp_servers_immutable`: repeat the parent name and replace hyphens with underscores.

`ansible/playbooks/servers/system/workload_preflight.yml` requires a nonblank
address before connecting and a regular image marker before system configuration.
Add the container to inventory:

1. Apply the root and commit the fragment it writes. The plan shows the file
   before the apply.
2. Create the group's secrets with `task sops:edit`, at
   `ansible/inventory/servers/group_vars/grp_servers_immutable_<host>/secrets.sops.yaml`.
   Set `ansible_host` to the `ct_ipv4` from the output above. That leaf holds
   the address alone. `ansible_user` comes from
   `ansible/inventory/servers/group_vars/all/vars.yml`.
   A rename means editing that file and the account in both inventories'
   secrets.

**Node console access.** Images don't include a shared password.
PVE shell mode doesn't require one. From the node:

```sh
pct enter <ct_id>
pct console --cmode shell <ct_id>
```

Run these from the PVE node's `Shell` tab.
Follow logs with `pct exec <ct_id> -- journalctl -u <unit> -f`.
A real login prompt requires a per-clone password, set with `pct set <ct_id> --password`.

Whether the container's Console tab honours the shell mode is untested here.

**Set the address.** DHCP leases can change on reboot.
For a stable `ansible_host`, set an address in the workload's git-ignored tfvars:

```hcl
lxc_workloads = {
  tf-test = {
    id       = 1000
    template = "NAS:vztmpl/<artifact>"
    ipv4     = { address = "<address>/<prefix>", gateway = "<gateway>" }
  }
}
```

Replace the address, prefix, and gateway placeholders with your network values.
Omit `ipv4`, or set it to `null`, to use DHCP.

A static address also makes `ct_ipv4` available at apply time.
With DHCP, it can remain null until the lease is reported, while the Docker
bridge can satisfy the provider's wait first.

**Review DHCP drift.** Refresh can show `dhcp` changing to the leased address.
Applying that diff pins the address. Declare a static address explicitly when intended.

Then converge the one host, with owner approval:

```sh
task ansible:site -- -l <host>
```

Clones join `grp_servers_immutable`, outside the mutable Debian LXC branch.
Mutable system plays don't target them. Service groups remain independent.
The required marker path is `/etc/image-build-info`.

**Without SSH.** Use node access for containers without usable keys:

```sh
pct enter <ct_id>
pct exec <ct_id> -- journalctl -u <unit>
```

See [the Ansible shell](../../ansible/README.md) for workload policy and
[Add a Proxmox VE node](onboard-pve.md) for PVE inventory.

## Add a storage mount point

Use a storage-backed volume with this root's API token.
Host bind mounts need `root@pam` authentication without an API token.
Edit the workload entry in the git-ignored tfvars:

```hcl
mountpoints = [{
  volume = "local-lvm"
  path   = "/srv/data"
  size   = "10G"
  backup = true
}]
```

Sizes require a `K`, `M`, `G`, or `T` suffix. `disk` remains numeric, in gibibytes.
Replace existing unitless sizes with values that match the volume size.
Don't append `G` to a byte count.
Review the plan for replacement before applying a size change, with owner approval.
`backup = true` includes the volume in PVE backups. It doesn't create a backup.

## Destroy

Get owner approval before changing protection or deleting the workload.

If protection is enabled, complete these steps first:

1. Disable protection.
2. Apply the protection change.

With protection disabled, complete the deletion:

1. Delete the workload's entry from `lxc_workloads` in the local tfvars.
2. Save a plan with `task tf:proxmox-jarvis-plan -- -out=delete.tfplan`.
3. Review the resource and disk deletions.
4. Apply the approved plan with `task tf:proxmox-jarvis-apply -- delete.tfplan`.

The state defines resource ownership. A `terraform` tag alone doesn't import or delete a container.

Don't use a root-wide destroy to remove one container.
The root also manages optional VM workloads and downloaded VM images.
VM deletion guards block a root-wide destroy by default.
See [Workload deletion protection](../../terraform/README.md#workload-deletion-protection).
Removing a workload leaves its source image in place.
Removing a `vm_image_downloads` pin deletes that downloaded image from Proxmox.

## Select a newer image

1. Rebuild the image with a new build number.
2. Change the workload's `template` in the git-ignored tfvars.
3. Review the replacement and disk deletions.
4. Get owner approval before applying.

## A second PVE server

Create a root named after the server with a separate state key, access root
under `terraform/bootstrap/pve/`, and git-ignored tfvars.
Reuse `proxmox/modules/lxc/` and declare the new node's facts in `locals.tf`.

## Next steps

- [Add a Proxmox VE node](onboard-pve.md): the node this root targets.
- [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md):
  the token this root authenticates with.
- [Terraform state design](../../terraform/BACKEND.md): the bucket this root
  writes to.
