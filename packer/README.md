# packer/

Native Packer templates and recipes for Debian 13 LXC images on Proxmox VE.

## Layout

| Path | Holds |
| ---- | ----- |
| `templates/proxmox-lxc/` | Shared plugin pin, source, typed inputs, provisioner, and native manifest |
| `images/<os>/lxc/<product>.pkrvars.hcl` | Product identity, exact parent, resources, and Ansible target |
| `templates/proxmox-vm/.gitkeep` | Reserved VM backend directory, not executable |
| `images/debian-13/vm/.gitkeep` | Reserved VM recipe directory, not executable |
| `hosts/jarvis.pkrvars.hcl` | Public storage and bridge facts |
| `hosts/jarvis.local.pkrvars.hcl` | Ignored connection inputs, mode 600 |
| `manifests/<build-id>/packer.json` | Ignored native manifest for one build |

Packer loads one backend directory and explicit recipe and node variable files.
A recipe selector omits `images/` and the `.pkrvars.hcl` suffix. For example,
`debian-13/lxc/base` selects the base recipe.
The VM directories reserve the layout only. They contain no builder, plugin,
variables, or runnable task.

## Image contract

The base recipe uses two cores, 2048 MiB, and an 8 GiB root filesystem.
The Docker recipe uses two cores, 4096 MiB, and a 16 GiB root filesystem.
Both recipes use unprivileged containers with nesting and keyctl.
Container identifiers `900` and `901` remain compatibility inputs.
They don't prove container ownership.

Every invocation gets one Coordinated Universal Time (UTC) timestamp and one
version-4 Universally Unique Identifier (UUID) from Task.
The archive name is:

```text
homelab-<image-id>-lxc_<build-id>_<arch>.tar.zst
```

Each recipe pins an exact parent basename.
The public node file supplies its storage.
Changing a parent doesn't change the child product identity.
The native manifest records the image, parent, build ID, source revision,
and declared plugin source/version.
It doesn't record or verify the parent or output checksum.

Packer's native Ansible provisioner uses the builders inventory for LXC builds.
It passes the same inventory directory as `task ansible:image`. Ansible owns
parent, image, and service group membership.
The provisioner disables Packer's SSH proxy and keeps
`community.proxmox.proxmox_pct_remote`. That connection reaches PVE with Paramiko
and runs commands through `pct exec`. Packer supplies the PVE address, SSH user,
key path, container ID, and image facts. Each recipe selects its host alias.
Docker inheritance comes from its Packer parent, not Ansible group membership.

Adding an LXC product needs one recipe and one Ansible target. The shared HCL
and Taskfile don't enumerate product names.

## Tasks

Local checks don't contact managed hosts:

```sh
task packer:fmt
task packer:fmt-check
task packer:init
task packer:validate
```

The first `task packer:init` downloads the pinned plugin and needs network.
`task packer:init -- -force` deliberately reinstalls that dependency.

Build tasks contact the selected PVE node and need owner approval:

```sh
task packer:build RECIPE=debian-13/lxc/base HOST=jarvis
task packer:build-all HOST=jarvis
```

`build` runs exactly one selected recipe. `build-all` discovers every LXC
recipe, sorts them by selector, and stops on the first failure. Each invocation
gets its own immutable archive name and native manifest.

The batch command doesn't connect one output to the next recipe. Docker still
uses the exact parent committed in its recipe. Update that recipe deliberately
when Docker must consume a newer base.

Extra arguments after `--` reach `packer build`.
Use them only with the same owner approval as the build.
The public tasks run Ansible dependency setup before Packer.

## Current plugin limits

The pinned `github.com/leoarry/proxmox-lxc` version `0.1.5` remains operational,
but it hasn't passed the proposed release-safety qualification.
It doesn't provide all required controls for:

- Parent digest verification during consumption.
- Ownership-safe fixed container identifiers and cleanup.
- Invocation-specific dump selection.
- Verified SSH host keys.
- Atomic, no-overwrite publication on the NAS.

Treat these as known risks, not implemented controls.
Get owner approval before every build and inspect existing build identifiers
and destination archives first.
Plugin hardening belongs in the maintained plugin and its Go test suite.
It doesn't belong in a repository-specific Python or shell release framework.

See [Build and qualify the golden images](../docs/runbooks/build-base-image.md)
for the operating procedure and qualification boundary.
