# packer/

Packer templates and recipes for Debian 13 LXC images on Proxmox VE.

## Layout

| Path | Content |
| --- | --- |
| `templates/proxmox-lxc/` | Plugin pin, source, typed inputs, provisioner, and native manifest |
| `images/<os>/lxc/<product>.pkrvars.hcl` | Product identity, exact parent, resources, and Ansible target |
| `templates/proxmox-vm/.gitkeep`, `images/debian-13/vm/.gitkeep` | Reserved VM directories without runnable builders, variables, or tasks |
| `hosts/jarvis.pkrvars.hcl` | Public storage and bridge facts |
| `hosts/jarvis.local.pkrvars.hcl` | Ignored connection inputs, mode 600 |
| `manifests/<build-id>/packer.json` | Ignored native build manifest |

Packer loads one backend directory with explicit recipe and node variable files.
Recipe selectors omit `images/` and `.pkrvars.hcl`: `debian-13/lxc/base` selects
the base recipe.

## Image contract

| Recipe | Cores | Memory | Root filesystem | Compatibility container ID |
| --- | ---: | ---: | ---: | ---: |
| Base | 2 | 2048 MiB | 8 GiB | 900 |
| Docker | 2 | 4096 MiB | 16 GiB | 901 |

Both use unprivileged containers with nesting and keyctl.
The compatibility IDs don't establish container ownership.
Task combines a Coordinated Universal Time (UTC) timestamp with a version-4
Universally Unique Identifier (UUID) for each build ID:

```text
homelab-<image-id>-lxc_<build-id>_<arch>.tar.zst
```

Recipes pin exact parent basenames. Storage comes from the public
`hosts/<node>.pkrvars.hcl` file.
Changing a parent doesn't change the child product identity.
The native manifest records the image, parent, build ID, source revision,
and declared plugin source/version. It doesn't record or verify archive checksums.

The native Ansible provisioner uses the same builders inventory as
`task ansible:image`. It disables Packer's SSH proxy and uses
`community.proxmox.proxmox_pct_remote` through Paramiko and PVE `pct exec`.
Packer supplies the address, SSH user, key path, container ID, and image facts.
Each recipe selects an inventory host alias. Ansible defines group membership,
while Packer defines Docker's parent artifact.

A new LXC product needs one recipe and one Ansible target. The shared HCL and
Taskfile don't enumerate products.

## Tasks

Local checks don't contact managed hosts:

```sh
task packer:fmt
task packer:fmt-check
task packer:init
task packer:validate
```

The first `task packer:init` needs network access to download the pinned plugin.
`task packer:init -- -force` reinstalls it.

Builds require owner approval before contacting the selected PVE node:

```sh
task packer:build RECIPE=debian-13/lxc/base HOST=jarvis
task packer:build-all HOST=jarvis
```

`build` runs one recipe. `build-all` sorts discovered LXC recipes by selector
and stops on failure. Each invocation creates a separate archive name and manifest.
The batch doesn't change committed parents: update the Docker recipe explicitly
to select a newer base.

Arguments after `--` pass to `packer build` and require the same approval.
The public tasks run Ansible dependency setup before Packer.

## Current plugin limits

The pinned `github.com/leoarry/proxmox-lxc` version `0.1.5` is operational but
hasn't passed release-safety qualification. It lacks qualified controls for:

- Parent digest verification during consumption.
- Container ownership checks and cleanup.
- Invocation-specific dump selection.
- SSH host-key verification.
- Atomic, no-overwrite publication on the NAS.

Get approval for each build after reviewing these risks and existing container
identifiers and destination archives. Maintain hardening controls and Go tests
in the plugin project. Don't add a repository-specific Python or shell release framework.

Follow [Build and qualify the golden images](../docs/runbooks/build-base-image.md)
for the operating procedure and qualification requirements.
