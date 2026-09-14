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

The two commands below read the node and then change it. Expect one container
to add.

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

The `lxcs` output lists every workload with its `ct_id` and its `ct_ipv4`.

Then, on the node, the full chain proof. The clone runs Docker from the golden
image with no manual step:

```sh
pct exec <ct_id> -- docker run --rm hello-world
pct exec <ct_id> -- cat /etc/image-build-info
```

The marker carries the image name, its version, and its parent, and the common
spoke asserts it on cattle.

## Destroy

One command removes the container. The golden image is untouched.

```sh
task tf:jarvis-apply -- -destroy -auto-approve
```

The destroy removes the container and its disk. The golden image stays in the
template storage. To move a workload to a newer image, rebuild it with a
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
