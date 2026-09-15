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

- The apply takes the state lock. The backend sets `use_lockfile`, which needs
  S3 conditional writes. OVH S3 supports them. A hang on `Acquiring state
  lock` means the test failed. Set `use_lockfile` to `false`, record the
  reason in [Terraform state design](../../terraform/BACKEND.md), and run
  again.
- The container boots with fresh SSH host keys, no machine-id, and no apt
  package lists. That's the `image_finalize` role's contract for the golden
  image.

## Check the container

Read the workload list, then prove the chain end to end on the node.

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

The marker carries the image name, its version, and its parent, and the
bootstrap layer asserts it on cattle.

## The container joins the fleet

The image carries the fleet account, so the container answers SSH from birth,
for Ansible and for you. A new device means a new public key in
`ansible/inventory/builders/group_vars/all/secrets.sops.yaml`, added with
`task sops:edit`. Then rebuild the image chain: the old key stays trusted in
every archive built before.

The workloads root writes the group its apply creates, one fragment per node
at `ansible/inventory/servers/iac.tf.<node>.yml`. The fragment carries the
group, the host, and the container id, and no address, so it stays cleartext
and committed. A workload named `tf-test` lands in `grp_tf_tf_test`: the group
name uses underscores in place of hyphens, because Ansible reports a warning
on a hyphen. The bootstrap layer asserts the address for a cattle host, so a
missing step 2 fails loudly.

Then the container is a fleet host in two steps:

1. Apply the root and commit the fragment it writes. The plan shows the file
   before the apply.
2. Create the group's secrets with `task sops:edit`, at
   `ansible/inventory/servers/group_vars/grp_tf_<host>/secrets.sops.yaml`.
   `ansible_host` is the `ct_ipv4` from the output above. `ansible_user` is
   the fleet account, `admin` unless you renamed it in the image secrets.

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
    ipv4     = { address = "10.0.0.5/24", gateway = "10.0.0.1" }
  }
}
```

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

The bootstrap layer asserts `/etc/image-build-info` on a cattle host, so it
proves the image. A clone never joins `grp_baseline`, so no baseline play
targets it and the first convergence changes nothing.

**Without SSH.** An image built before the keys, or a container you want to
reach with no key at all, still answers on the node:

```sh
pct enter <ct_id>
pct exec <ct_id> -- journalctl -u <unit>
```

See [the Ansible shell](../../ansible/README.md) for the cattle model, and
[Add a Proxmox VE node](onboard-pve.md) for the same inventory mechanics on a
PVE host.

## Destroy

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
