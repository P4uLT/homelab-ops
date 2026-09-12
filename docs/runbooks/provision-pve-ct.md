# Provision an LXC workload with Terraform

The `terraform/proxmox/jarvis/` root instantiates Packer golden images
as LXC containers on the PVE node jarvis. The shared
`terraform/proxmox/modules/lxc/` module wraps one container. The root
holds one module call per workload, and its `locals.tf` holds the node
facts: the node name, the storages, the bridge, and the image pins.
The provider talks to the PVE API over HTTPS with an API token. One
root covers one PVE server. The state lives in the shared OVH bucket.
The design is in `terraform/BACKEND.md`.

Prerequisites:

- The golden images are in the node template storage. Build them first:
  `docs/runbooks/build-base-image.md`.
- `.env.tf` holds `TF_VAR_state_passphrase`, the `AWS_*` state
  backend keys, and `TF_VAR_bucket_name`.
- Owner approval for every run. A plan reads the node. An apply changes
  it.

## Mint the PVE API credential, one time

Run on the node, as root:

```sh
pveum user add terraform@pve --comment "OpenTofu root jarvis"
pveum role add Terraform -privs "Datastore.AllocateSpace Datastore.Audit \
  VM.Allocate VM.Audit VM.Config.Network VM.Config.Options \
  VM.Monitor VM.PowerMgmt"
pveum aclmod / --users terraform@pve --roles Terraform
pveum user token add terraform@pve tf --privsep 0
```

The privilege set is the lean set for an unprivileged container from
the template storages: create, start, stop, destroy, and read. A call
that misses a privilege fails with `403 Permission check error`. The
PVE log names the privilege. Add it to the role and retry, and record
the addition here.

The token prints once, at creation. Copy the whole
`terraform@pve!tf=<secret>` value. A loss means a new token.

Then create `terraform/proxmox/jarvis/jarvis.local.auto.tfvars` from
`jarvis.local.auto.tfvars.example`, mode 600:

- `pve_endpoint`: the node address on your LAN, port 8006.
- `pve_api_token`: the full token value.

The root sets `insecure = true` in code, because PVE ships a
self-signed certificate.

## First apply

```sh
mise exec -- task tf:jarvis-plan
mise exec -- task tf:jarvis-apply -- -auto-approve
```

The plan shows one container to add. The apply clones the archive of
`ct_template` (the Docker golden image by default), starts the
container, and writes the state to the bucket.

Two checks on this first run:

- The apply takes the state lock. The backend sets `use_lockfile`,
  which needs S3 conditional writes. OVH S3 supports them. A hang on
  `Acquiring state lock` means the test failed. Set `use_lockfile` to
  `false`, record the reason in `BACKEND.md`, and run again.
- The container boots with fresh SSH host keys, no machine-id, and no
  apt package lists. That is the `90-finalize.sh` contract of the
  golden image.

## Check the container

```sh
mise exec -- task tf:jarvis-output -- -json lxcs
```

The `lxcs` output lists every workload with its `ct_id` and its `ct_ipv4`.

Then, on the node, the full chain proof. The clone runs Docker from
the golden image with no manual step:

```sh
pct exec <ct_id> -- docker run --rm hello-world
```

## Destroy

```sh
mise exec -- task tf:jarvis-apply -- -destroy -auto-approve
```

The destroy removes the container and its disk. The golden image stays
in the template storage. To move a workload to a newer image, rebuild
the image with a bumped build number, then change its pin in the
`images` map of the root's `locals.tf`.

## A second PVE server

Copy the pattern, not the code: a new root named after the new server,
its own state key, its own token, its own `.env.<server>.tf`. The root
consumes the same `proxmox/modules/lxc/` and declares the new node's
facts in its `locals.tf`.
