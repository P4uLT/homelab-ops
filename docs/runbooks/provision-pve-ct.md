# Provision an LXC workload with Terraform

The `terraform/proxmox/jarvis/` root instantiates Packer golden images as LXC
containers on the PVE node jarvis. The shared `terraform/proxmox/modules/lxc/`
module wraps one container. The root holds one entry per workload in its
`lxc_workloads` map, which lives in the git-ignored tfvars. Its `locals.tf` holds
the node facts: the node name, the storages, and the bridge. The provider talks
to the PVE API over HTTPS with an API token. One root covers one PVE server. The state lives in the shared OVH
bucket. The design is in [Terraform state design](../../terraform/BACKEND.md).

Prerequisites:

- The golden images are in the node template storage. Build them first:
  [Build the golden images](build-base-image.md).
- `.env.tf` holds `TF_VAR_state_passphrase`, the `AWS_*` state backend keys,
  and `TF_VAR_bucket_name`.
- Owner approval for every run. A plan reads the node. An apply changes it.

## PVE API access

The role, the group, the user `terraform-prov@pve`, the ACL, and the API token
are Terraform-managed by `terraform/bootstrap/pve/jarvis/`. Run that root once,
following [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md),
and copy its `token_value` output.

Then create `terraform/proxmox/jarvis/jarvis.local.auto.tfvars` from
`jarvis.local.auto.tfvars.example`, mode 600:

- `pve_endpoint`: the node address on your LAN, port 8006.
- `pve_api_token`: the full token value, `terraform-prov@pve!tf=<secret>`.

The root sets `insecure = true` in code, because PVE ships a self-signed
certificate.

## Apply the first container

The two commands below read the node and then change it.

```sh
task tf:jarvis-plan
task tf:jarvis-apply -- -auto-approve
```

The plan shows one container to add. The apply clones the archive its entry
names as `template`, the Docker golden image here, starts the container, and
writes the state to the bucket.

Two checks on this first run:

- The apply takes the state lock with `use_lockfile`. OVH S3 supports conditional writes.
  If lock acquisition stalls, check for an active writer or a stale lock.
  Don't disable locking to bypass the failure. Get owner approval before clearing a confirmed stale lock.
- The container boots with fresh SSH host keys, no machine-id, and no apt
  package lists. That's the `image_finalize` role's contract for the golden
  image.

## Check the container

Read the workload list in a private terminal, then prove the chain end to end on the node.
`lxcs` contains addresses and is sensitive. Ordinary plan and apply output masks it.
Default output without a name masks it too, after an apply records the sensitivity metadata.
This doesn't mask network attributes in resource diffs.
Explicit named output and `-json` or `-raw` can print sensitive values in plaintext.
Don't send them to shared logs or tracked files.

```sh
task tf:jarvis-output -- -json lxcs
```

The `lxcs` output is keyed by workload name, and each entry carries its
`ct_id` and its `ct_ipv4`.

Then, on the node, the full chain proof. The container reaches Docker Hub over
its DHCP address, so the pull needs outbound HTTPS. The clone runs Docker from
the golden image with no manual step:

```sh
pct exec <ct_id> -- docker run --rm hello-world
pct exec <ct_id> -- cat /etc/image-build-info
```

The marker records the image name, its version, and its parent.
The baseline layer checks that the marker is a regular file, not its contents.

## The container joins the fleet

The image carries the fleet account, so the container answers SSH from birth,
for Ansible and for you. A new device means a new public key in both
inventories, added with `task sops:edit`. The builders copy feeds the image,
and the servers copy feeds the hosts built by hand. Then rebuild the image
chain: the old key stays trusted in every archive built before.

The workloads root writes the group its apply creates, one fragment per node
at `ansible/inventory/servers/iac.tf.<node>.yml`. The fragment carries the
group, the host, and the container id, and no address, so it stays cleartext
and committed. A workload named `tf-test` lands in
`grp_servers_immutable_tf_test` under `grp_servers_immutable`. The leaf repeats
its parent's name and replaces hyphens with underscores. `ansible/playbooks/servers/system/workload_preflight.yml` requires an
explicit, nonblank address before connecting. It then checks for a regular
image marker file before system configuration.

Then the container is a fleet host in two steps:

1. Apply the root and commit the fragment it writes. The plan shows the file
   before the apply.
2. Create the group's secrets with `task sops:edit`, at
   `ansible/inventory/servers/group_vars/grp_servers_immutable_<host>/secrets.sops.yaml`.
   Set `ansible_host` to the `ct_ipv4` from the output above. That leaf holds
   the address alone. `ansible_user` comes from
   `ansible/inventory/servers/group_vars/all/vars.yml`.
   A rename means editing that file and the account in both inventories'
   secrets.

**Reaching a container.** The image carries no password, on purpose: a shared
one would leak into every clone. The workloads ask for none either: their
console runs in shell mode, where PVE invokes a shell without a login. From the
node:

```sh
pct enter <ct_id>
pct console --cmode shell <ct_id>
```

The node's `Shell` tab in the PVE interface reaches both. For a log, `pct exec
<ct_id> -- journalctl -u <unit> -f`. A real login prompt wants a password, and
that's a per-clone choice: `pct set <ct_id> --password`.

Whether the container's Console tab honours the shell mode is untested here.

**Set the address.** The module defaults to DHCP, so `ansible_host` can move
on a reboot and the SSH habit with it. A workload you reach often takes a
static address instead, in its entry in the git-ignored tfvars:

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

A static address has a second effect. The provider reads the interface's
address right after creation, so the `ct_ipv4` output is true at apply time.
DHCP leaves it null until the container reports a lease, and the Docker bridge
answers the provider's wait before that.

**A DHCP workload drifts.** The provider reads the container's address after
creation, so a workload left on DHCP can show `dhcp` turning into the leased
address. Applying that pins the address without anyone deciding it. Declare the
address here when you want it fixed.

Then converge the one host, with owner approval:

```sh
task ansible:site -- -l <host>
```

The `workload_preflight` play requires a regular `/etc/image-build-info` file on each workload.
It doesn't verify image version or provenance.
A clone joins `grp_servers_immutable`, outside `grp_servers_mutable` and its
Debian LXC branch. Mutable system plays don't target it. Service groups remain
independent of the maintenance populations.

**Without SSH.** An image built before the keys, or a container you want to
reach with no key at all, still answers on the node:

```sh
pct enter <ct_id>
pct exec <ct_id> -- journalctl -u <unit>
```

See [the Ansible shell](../../ansible/README.md) for the workload model, and
[Add a Proxmox VE node](onboard-pve.md) for the same inventory mechanics on a
PVE host.

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

If protection is enabled, disable it and apply that change with owner approval before removing the entry.
To remove one workload, delete its entry from `lxc_workloads` in the local tfvars.
With owner approval, save a plan with `task tf:jarvis-plan -- -out=delete.tfplan`.
Review the resource and disk deletions before applying `task tf:jarvis-apply -- delete.tfplan`.

The state defines resource ownership. A `terraform` tag alone doesn't import or delete a container.

One command removes every workload in this root's state. The golden image is
untouched.

```sh
task tf:jarvis-apply -- -destroy -auto-approve
```

The destroy removes the workloads and their disks. The golden image stays in
the template storage. To move a workload to a newer image, rebuild it with a
bumped build number, then change its `template` in the git-ignored tfvars.

## A second PVE server

Copy the pattern, not the code. A new root named after the new server, with
its own state key, its own access root under `terraform/bootstrap/pve/`, and
its own git-ignored tfvars. The root consumes the same `proxmox/modules/lxc/`
and declares the new node's facts in its `locals.tf`.

## Next steps

- [Add a Proxmox VE node](onboard-pve.md): the node this root targets.
- [Bootstrap the PVE access of the Terraform roots](bootstrap-pve-access.md):
  the token this root authenticates with.
- [Terraform state design](../../terraform/BACKEND.md): the bucket this root
  writes to.
