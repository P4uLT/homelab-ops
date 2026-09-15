# Provision an LXC workload with Terraform

The `terraform/proxmox/jarvis/` root instantiates Packer golden images as LXC
containers on the PVE node jarvis. The shared `terraform/proxmox/modules/lxc/`
module wraps one container. The root holds one module call per workload, and
its `locals.tf` holds the node facts: the node name, the storages, the bridge,
and the image pins. The provider talks to the PVE API over HTTPS with an API
token. One root covers one PVE server. The state lives in the shared OVH
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

The plan shows one container to add. The apply clones the archive pinned in
`local.images.docker`, the Docker golden image, starts the container, and
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

The marker carries the image name, its version, and its parent, and the common
layer asserts it on cattle.

## First contact, then the inventory

Ansible reaches every other host over SSH with a key. A golden image carries
no key, on purpose, and the container has no password to fall back on. So the
node gives the container its first key, through `pct`.

Run these commands on the node. `<public-key-path>` is the public half of the
automation key:

```sh
pct exec <ct_id> -- install -d -m 700 /root/.ssh
pct push <ct_id> <public-key-path> /root/.ssh/authorized_keys
pct exec <ct_id> -- chmod 600 /root/.ssh/authorized_keys
```

The container answers SSH for that key now, for Ansible and for you. Add your
own device key to the same file: one automation key, one personal key per
device, as [SSH key and host-key practices](../ssh.md) requires. The node
gets you in without any key at all, which suits a quick look at the logs:

```sh
pct enter <ct_id>
pct exec <ct_id> -- journalctl -u <unit>
```

Then the container is a fleet host like any other:

1. Add the leaf group `grp_tf_<host>` to `groups.yml`, under `grp_servers`.
2. Add the host to `hosts.yml`, inside that group.
3. Store the host in the group's `secrets.sops.yaml`. `ansible_host` is the
   `ct_ipv4` from the output above. `ansible_user` is `root`, the only account
   the image carries.

**Choose the address.** The module defaults to DHCP, so `ansible_host` can
move on a reboot and the SSH habit with it. A workload you reach often wants a
static `ipv4.address` in the root's git-ignored tfvars, never in a tracked
file.

Then converge the one host, with owner approval:

```sh
task ansible:site -- -l <host>
```

The common layer asserts `/etc/image-build-info` on a cattle host, so it proves
the image and skips the OS baseline. The rest comes from `common_profiles` in
the group's `group_vars`. No group defines that variable yet, so the first
convergence changes nothing.

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
bumped build number. Then change its pin in the `images` map of the root's
`locals.tf`.

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
