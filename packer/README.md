# packer/

Golden LXC images for Proxmox VE, built by Packer on a PVE node.

| Path | Holds |
| ---- | ----- |
| `images/<name>.pkr.hcl` | one image: build number, parent, resources, scripts |
| `images/base.pkr.hcl` | the plugin, and the variables every image shares |
| `hosts/<node>.pkrvars.hcl` | the node facts: template volid, artifact storage and dir, rootfs storage, bridge |
| `hosts/<node>.local.pkrvars.hcl` | git-ignored: the node address, login, key or password |
| `_common/*.sh` | provisioning scripts; every image lists its own, and `90-finalize.sh` always runs last |

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
from the node's `artifact_storage`, so a node keeping its artifacts
elsewhere needs no image change. Each image carries only its build number:
bump it when its content changes, never to rebuild the same content.
Terraform instantiates the archives under that name.

What the images contain:

- Debian 13, upgraded at build time.
- `debian-13-standard-base`: `curl` and `ca-certificates`, systemd's
  networkd wait unit disabled.
- the Docker image: the base plus Docker Engine from the upstream
  repository in deb822 source form, with the buildx and compose plugins.
  Container logs go to journald.
- Every image ends with `90-finalize.sh`: no machine-id, no SSH host keys,
  a locked root password, and no apt package lists. Each clone generates
  fresh host keys on first start.

Build: `task packer:build`. Procedure: `docs/runbooks/build-base-image.md`.
