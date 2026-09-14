# Build the golden images

A golden image is a Packer build on a PVE node. The build creates a container
template, Ansible provisions it, then Packer packs it with vzdump as a
versioned archive. Terraform instantiates those archives. Never patch a clone
in place.

The images form a chain: the base builds on the official Debian template, the
Docker image on the base.

The plugin connects to the node over plain SSH and runs `pct`. It doesn't use
the PVE API.

## Node files

Two files per node, both under `packer/hosts/`:

- `<node>.pkrvars.hcl`, committed. The non-secret facts: `parent_template`
  (the official template volid, `<storage>:vztmpl/<file>`),
  `artifact_storage` and `artifact_dir` (where builds write artifacts and
  clones address them), `ct_storage`, `ct_bridge`.
- `<node>.local.pkrvars.hcl`, git-ignored. The connection: `pve_ssh_host`,
  `pve_ssh_user`, and either `pve_ssh_key_path` (absolute, passphrase-less) or
  `pve_ssh_password`. Prefer the key: the plugin connects without checking the
  host key, see [SSH key and host-key practices](../ssh.md).

The build passes both, so a missing local file stops the build instead of
aiming at another node.

## Before the first build

Four steps, once per node. The first two read facts off the node, so they need
access to it.

1. Put the Debian 13 template on the storage the node reads, then read back
   its exact file name:

   ```sh
   pveam update
   pveam download <storage> <template from pveam available>
   pveam list <storage> | grep debian-13
   ```

   Copy it into `parent_template` as a full volid. Proxmox ships several
   builds of the same release (`13.6-1`, `13.6-2`) and a build stops on a name
   the node doesn't have.

2. Read the storage and bridge names off the node:

   ```sh
   pvesm status
   ip -br link show type bridge
   ```

   They go into that same committed file. PVE mounts an NFS storage under
   `/mnt/pve/<id>`, with its templates in `template/cache`.

3. Create `<node>.local.pkrvars.hcl`, mode 600, with the connection. The
   build authenticates with `pve_ssh_key_path`. The Ansible step runs through
   paramiko, which needs a key or an agent. A password-only file stops the
   build at the playbook.

4. Run `task packer:init` once. Later runs stay offline.

## Run the build

`task packer:build` contacts the node. Get owner approval first. It builds
every image of `PKR_IMAGES`, in order, on every node of `PKR_HOSTS`. Each
build creates a container from the parent template and runs the image playbook
from this workstation. It then writes a vzdump archive in the template storage
and destroys the container.

The archive name carries the chain that produced it and the position in that
chain:

```text
NAS:vztmpl/debian-13-standard-base_13.6-1_amd64.tar.zst
```

Bump `base_build` or `docker_build` in `packer/images/<name>.pkr.hcl` to build
a new one. Packer overwrites a file of the same name, so a rebuild without a
bump replaces the archive already in the storage.

An image pins its parent by file name, `<name>_parent`, and the storage comes
from the node's `artifact_storage`. To rebuild one image, on every node or on
one:

```sh
task packer:build-docker
task packer:build-one IMAGE=docker HOST=jarvis
```

Each build writes `packer/manifests/<image>.json` (git-ignored): the artifact,
its version, and its parent.

## When a build stops at `pct create`

The plugin captures that command's error output and never prints it, so Packer
only reports `command exited with status 255`. Check the three preconditions
it relies on, then run the command by hand for the real error:

```sh
pvesm status
pveam list <storage>
ip -br link show <bridge>
```

The plugin destroys its container on any failure. Only a killed Packer process
leaves one behind, and each image pins its build container id (`<name>_ctid`),
so the next build reuses it. Destroy it first when its content is suspect:

```sh
pct list
pct destroy <ctid>
```

## Verify a fresh image

An archive is a container filesystem, so the contract is worth reading once on
a throwaway clone. Create one from the archive, boot it, then check the four
things `image_finalize` promised:

```sh
pct create 99900 NAS:vztmpl/<archive> --hostname image-check --unprivileged 1 \
  --features nesting=1,keyctl=1 --rootfs local-lvm:8 --memory 512 --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp
pct start 99900
pct exec 99900 -- cat /etc/image-build-info
pct exec 99900 -- passwd -S root
pct exec 99900 -- ls -A /var/lib/apt/lists | wc -l
pct stop 99900
pct destroy 99900
```

Expected: the marker holds the image name, version, and parent. `passwd -S
root` reports `root L`, the locked account. The apt list is empty. The clone
generates its own host keys at that first boot, which is why `/etc/ssh` looks
populated here and empty in the archive. Stop the container before the
destroy: `pct destroy` refuses a running one.

## When a build stops at the Ansible step

The playbook is idempotent and the container id is pinned, so a failure is a
fix-and-retry, not a rebuild:

```sh
task packer:build-one IMAGE=base HOST=jarvis -- -on-error=ask
```

Answer `retry` and Packer re-runs the provisioner on the container that's
already there. To run the playbook by hand instead, call the same task Packer
calls, with your own node facts:

```sh
task ansible:image -- --limit builder-base \
  -e ansible_host=<node-ip> -e ansible_user=<node-login> \
  -e ansible_private_key_file=<key-path> -e proxmox_vmid=900 \
  -e image_name=base -e image_version=manual -e image_parent=manual
```

## Add an image

Five touch points:

1. The image play, in its category under `ansible/playbooks/image/`. A
   service image sits at `services/<name>.yml` and imports the roles of this
   image only. A stack image sits at `stacks/<name>.yml` with its own
   `stacks/<name>/` directory of plays, like the fleet's `servers/stacks/`.
2. Its line in the category's `all.yml`. `stacks/all.yml` already holds a
   placeholder play that matches no host. The first stack replaces the
   placeholder with its line and touches nothing else in the tree. The
   phases every build shares live in `common/`: the interpreter prologue,
   the base, and the seal.
3. The builders inventory, in `ansible/inventory/builders/`: the
   `grp_builders_<name>` leaf in `groups.yml`, then the `builder-<name>` host
   under it in `hosts.yml`. The selection is the host limit, so a missing
   host skips the play. An image that installs a service also joins that
   service's group, which is where its policy lives, in `group_vars/`.
4. `packer/images/<name>.pkr.hcl`, with its own `<name>_build`,
   `<name>_parent`, and `<name>_ctid` variables: Packer variable and local
   names are global to the directory, so they carry the image name. Give it a
   source and a build block named `<name>`, so `-only=proxmox-lxc.<name>`
   matches.
5. `<name>` in `PKR_IMAGES` in `.taskfiles/packer.yml`.

`task packer:validate` checks the last two exist before a build touches the
node.

## Next steps

- [Provision an LXC workload with Terraform](provision-pve-ct.md): instantiate
  the archive with a container.
- [Add a Proxmox VE node](onboard-pve.md): the node facts and the connection
  file this build needs.
- [Packaging notes](../../packer/README.md): the Packer shell and its tasks.
