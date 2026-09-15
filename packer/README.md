# packer/

Golden LXC images for Proxmox VE, built by Packer on a PVE node.

| Path | Holds |
| ---- | ----- |
| `images/<name>.pkr.hcl` | one image: build number, parent, resources, pinned container id, and the playbook it runs |
| `images/base.pkr.hcl` | the plugin, and the variables every image shares |
| `hosts/<node>.pkrvars.hcl` | the node facts: template volid, artifact storage and dir, rootfs storage, bridge |
| `hosts/<node>.local.pkrvars.hcl` | git-ignored: the node address, login, and key. A key, not a password: the Ansible step runs through paramiko, which takes neither a password prompt nor `~/.ssh/config` |

An image builds on the artifact of another, so the set is a chain:
`debian-13-standard-base` on the official Debian template,
`debian-13-standard-base-docker` on it. Each image reads the chain off its
own parent pin.

Artifacts are vzdump archives in the node template storage. A name is the
chain it came from, plus where it stands in it:

```text
debian-13-standard_13.6-1_amd64.tar.zst               official
debian-13-standard-base_13.6-1_amd64.tar.zst         base
debian-13-standard-base-docker_13.6-1_amd64.tar.zst  base + docker
```

An image pins its parent by file name (`docker_parent`). The storage comes
from the node's `artifact_storage`, so a node keeping its artifacts elsewhere
needs no image change. Each image carries only its build number. Bump it when
its content changes, never to rebuild the same content: an archive of the same
name is overwritten. Terraform instantiates the archives under that name.

What the images contain:

- Debian 13, upgraded at build time.
- `debian-13-standard-base`: `curl` and `ca-certificates`, systemd's
  networkd wait unit disabled.
- the Docker image: the base plus Docker Engine from the upstream
  repository in deb822 source form, with the buildx and compose plugins.
  Container logs go to journald.
- Every image ends with the `image_finalize` role: no machine-id, no SSH host
  keys, a locked root password, and no apt package lists. Each clone generates
  fresh host keys on first start. The role also writes
  `/etc/image-build-info`, the image identity the baseline layer asserts on
  the workload.
- The fleet account: a user, its public keys in `authorized_keys`, and its
  sudo options, validated by `visudo`. The `robertdebock.users` role creates
  it from the data in
  `ansible/inventory/builders/group_vars/all/secrets.sops.yaml`, encrypted
  like every other secret. The servers inventory declares the same account
  for the hosts built by hand. A public key opens nothing by itself, so it can
  travel in a versioned artifact. The private halves never do.

The build provisions through Ansible: `packer build` starts the container,
then a `shell-local` provisioner runs `task ansible:image` from this
workstation against it, through the PVE node. The build container needs no
sshd and carries no credential. One role set serves both the images and the
runtime baseline. The provisioning itself lives in `ansible/playbooks/image/`:
shared phases wrap one content play per image.

Build: `task packer:build` for everything, `task packer:build-base` or
`task packer:build-docker` for one image, and
`task packer:build-one IMAGE=<name> HOST=<node>` for one node. Procedure:
`docs/runbooks/build-base-image.md`.
