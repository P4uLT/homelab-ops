# Override the installed Packer plugin locally

Install a local `proxmox-lxc` development build in the default plugin registry,
then restore the pinned release. Validation and approved builds use the replacement.
This changes neither the Taskfile nor the committed pin and doesn't contact PVE.

## Before starting

- Use one zsh session with the project toolchain active.
- Start at the `homelab-ops` root. The plugin checkout is its sibling directory.
- Obtain owner approval for the development override and dependency downloads.
- Stop Packer processes before replacing the binary.
- Don't commit plugin binaries, credentials, or logs.

The local binary reports the pinned version for selection without configuration
changes. Publish neither that binary nor its version label as an upstream release.

## 1. Set up the shell

Run this block unchanged to read the release version from the project pin:

```zsh
unset PACKER_PLUGIN_PATH
PROJECT="$(pwd -P)"
PLUGIN_REPO="$(cd ../packer-plugin-proxmox-lxc && pwd -P)"
PLUGIN_SOURCE=github.com/leoarry/proxmox-lxc
PLUGIN_VERSION="$(python -c 'from pathlib import Path; import re; values = re.findall(r"(?m)^\s*version\s*=\s*\"([^\"]+)\"", Path("packer/templates/proxmox-lxc/plugins.pkr.hcl").read_text()); assert len(values) == 1 and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", values[0]), "Expected one exact release version pin"; print(values[0])')"
LOCAL_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/packer-proxmox-local.XXXXXX")"
chmod 700 "$LOCAL_ROOT"
printf 'Plugin version: %s\n' "$PLUGIN_VERSION"
```

Stop on command failure. `unset PACKER_PLUGIN_PATH` clears temporary registry
selection so these steps use the default registry.

## 2. Build and install the local replacement

Compile the intended plugin checkout:

```zsh
go -C "$PLUGIN_REPO" build -ldflags="-X github.com/leoarry/packer-plugin-proxmox-lxc/version.Version=$PLUGIN_VERSION" -o "$LOCAL_ROOT/packer-plugin-proxmox-lxc" .
```

Continue only if compilation succeeds. Install through Packer so it writes the
binary and its checksum together, replacing the installed release:

```zsh
packer plugins install --force --path "$LOCAL_ROOT/packer-plugin-proxmox-lxc" "$PLUGIN_SOURCE"
```

## 3. Validate locally

Check that the replacement loads with the project configuration:

```zsh
task packer:validate
```

Stop on failure. Validation doesn't establish a complete image build or release safety.
A version label and checksum sidecar don't qualify parent verification,
container ownership, SSH trust, or atomic publication.
Record the actual binary digest privately. Don't use this override for release builds.
Follow [Build and qualify the golden images](build-base-image.md).

## 4. Reinstall the official release

Stop Packer builds first.

The plugin version comes from `packer/templates/proxmox-lxc/plugins.pkr.hcl`.
`mise` pins the
`packer` binary, not the plugin. A plain `task packer:init` installs missing
plugins only, so it leaves the local build in place. `PACKER_PLUGIN_PATH` adds
plugin directories, so it doesn't reinstall or select a release.

Force Packer to install the pinned release, reading the version from the
configuration:

```zsh
task packer:init -- -force
task packer:validate
```

Or name the release explicitly:

```zsh
packer plugins install --force "$PLUGIN_SOURCE" "$PLUGIN_VERSION"
task packer:validate
```

In a new shell, repeat step 1 to set `PLUGIN_VERSION`. The force option replaces
the local binary without a separate removal.

Check the installed plugin listing:

```zsh
packer plugins installed | grep '/github.com/leoarry/proxmox-lxc/packer-plugin-proxmox-lxc_v'
```

Reinstallation restores the pinned binary but doesn't add the missing safety
controls. Update and qualify the dependency separately when a suitable release
is available. That change isn't part of this override procedure.
