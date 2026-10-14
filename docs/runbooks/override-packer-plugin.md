# Override the installed Packer plugin locally

Replace the installed `proxmox-lxc` plugin with a local build. Use this when a
change awaits review or merge, or whenever a local binary must run before a
release. The existing Task commands use that replacement.
Reinstall the pinned release from upstream to return to the official plugin.

This procedure changes the default plugin registry, not the Taskfile or the
committed version pin. It doesn't contact a Proxmox node.

## Before starting

- Use one zsh session with the project toolchain active.
- Start at the `homelab-ops` root. The plugin checkout is its sibling directory.
- Stop Packer builds before replacing the binary.
- Don't commit plugin binaries, credentials, or logs.

The local binary reports the version pinned by this project so Packer selects
it without a configuration change. It isn't the upstream release, even though
it reports the same version. Don't publish it as a release.

## 1. Set up the shell

Run this block unchanged. It reads the release version from the project pin, so
no version number needs manual substitution.

```zsh
unset PACKER_PLUGIN_PATH
PROJECT="$(pwd -P)"
PLUGIN_REPO="$(cd ../packer-plugin-proxmox-lxc && pwd -P)"
PLUGIN_SOURCE=github.com/leoarry/proxmox-lxc
PLUGIN_VERSION="$(python3 -c 'from pathlib import Path; import re; values = re.findall(r"(?m)^\s*version\s*=\s*\"([^\"]+)\"", Path("packer/images/common.pkr.hcl").read_text()); assert len(values) == 1 and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", values[0]), "Expected one exact release version pin"; print(values[0])')"
LOCAL_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/packer-proxmox-local.XXXXXX")"
chmod 700 "$LOCAL_ROOT"
printf 'Plugin version: %s\n' "$PLUGIN_VERSION"
```

Stop if a command fails. `unset PACKER_PLUGIN_PATH` clears an earlier
temporary-registry selection from this shell, so the steps target the default
registry.

## 2. Build and install the local replacement

Compile the intended plugin checkout:

```zsh
go -C "$PLUGIN_REPO" build -ldflags="-X github.com/leoarry/packer-plugin-proxmox-lxc/version.Version=$PLUGIN_VERSION" -o "$LOCAL_ROOT/packer-plugin-proxmox-lxc" .
```

Continue only if compilation succeeds. Install through Packer so it writes the
binary and its checksum together, replacing the installed release:

```zsh
packer plugins install --force --path "$LOCAL_ROOT/packer-plugin-proxmox-lxc" "$PLUGIN_SOURCE"
task packer:validate
```

Stop if a command fails. Successful validation proves the local plugin loads
with the existing configuration. It doesn't prove a complete image build.

## 3. Use the normal image tasks

No special registry prefix or new Task parameter is required:

```zsh
task packer:validate
```

For a real build, obtain owner approval and follow
[Build the base image](build-base-image.md). Confirm the configured container
belongs to the build or is unused. Confirm Ansible can decrypt its required
SOPS files before creating a container.

## 4. Reinstall the official release

Stop Packer builds first.

The plugin version comes from `packer/images/common.pkr.hcl`. `mise` pins the
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

`PLUGIN_VERSION` holds the version read from the project pin in step 1. Re-run
that block first if this is a new shell. Neither command needs the local build
removed first: the force option replaces it.

Confirm the registry now holds the release:

```zsh
packer plugins installed | grep '/github.com/leoarry/proxmox-lxc/packer-plugin-proxmox-lxc_v'
```

After upstream publishes the merged changes in a release, update the project
pin separately. That version change isn't part of this override procedure.
