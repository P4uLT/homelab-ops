# terraform/

OpenTofu roots and modules, grouped by provider and target.

## Layout

- `proxmox/`: one root per PVE server, using the
  [bpg provider](https://github.com/bpg/terraform-provider-proxmox).
  `proxmox/jarvis/` defines LXC workloads and imported-image VMs in separate
  maps in its git-ignored tfvars. Node facts are in the root's `locals.tf`.
- `proxmox/modules/lxc/`: one running container cloned from a golden image.
  DHCP is the default, with optional static addressing in tfvars.
- `proxmox/modules/vm/`: one VM booted from an imported QCOW2 image.
  The Jarvis root excludes VMs from Linux Ansible. See [VM image sources](#vm-image-sources)
  for download ownership and SSH requirements.
- `bootstrap/`: frozen credential and backend roots. `bootstrap/ovh/` creates
  the state backend and uses local state. `bootstrap/pve/<node>/` creates a
  node's Terraform access chain.
- `bootstrap/truenas/gen8/` owns the Gen8 pool, provisioning identity, local
  users and groups, and NFS and `cifs` services. `truenas/gen8/` owns
  datasets, permissions, shares, and the optional RustFS application. See the
  [TrueNAS bootstrap runbook](../docs/runbooks/bootstrap-truenas.md).
  Neither root manages dynamically provisioned Kubernetes volumes.
- `rustfs/gen8/` owns the RustFS buckets, one user and policy per bucket, and
  their quotas. It applies after the TrueNAS root installed the application.
  Its endpoint and keys live in the root's git-ignored `gen8.local.auto.tfvars`.
  The admin key pair matches the TrueNAS root's copy.
- `rustfs/modules/buckets/`: reusable bucket catalog with quotas, optional
  versioning, and a scoped user and policy per bucket. The caller configures
  the RustFS provider.
- `truenas/modules/dataset/`: one protected filesystem dataset with optional
  permissions and file shares. The Gen8 root calls it once per entry in `datasets`.
- `talos-lab/` (planned): discovery VMs only. Production Talos nodes use bare metal outside Terraform.

An LXC apply writes `ansible/inventory/servers/iac.tf.<node>.yml` with the
hostname and container ID, without an address. Workloads join
`grp_servers_immutable` through `grp_servers_immutable_<host>` leaves.
Leaf names repeat the parent name and replace hyphens with underscores.

State uses OVH S3, except the OVH bootstrap's local state. Read the
[state design](BACKEND.md) before a stateful run. Keep state out of git.

## Root rules

Group resources by provider, failure scope, and apply cadence, rather than type.
Give a new PVE server a root named after it. Restrict `bootstrap/ovh/` to the
state backend.

Declare the state key in each root's `backend.tf`, using
`<path>/terraform.tfstate`, as in `proxmox/jarvis/terraform.tfstate`.
A directory move doesn't move state. Keep the existing key unless a separate
[state migration](BACKEND.md#state-locations-and-code-moves) is approved.

## Root commands

Each scope exposes `task tf:<scope>-plan`, `-apply`, and `-output`:

| Scope | Root |
| --- | --- |
| `ovh-bootstrap` | `bootstrap/ovh` |
| `pve-jarvis-bootstrap` | `bootstrap/pve/jarvis` |
| `proxmox-jarvis` | `proxmox/jarvis` |
| `truenas-gen8-bootstrap` | `bootstrap/truenas/gen8` |
| `truenas-gen8` | `truenas/gen8` |
| `rustfs-gen8` | `rustfs/gen8` |

Pass native OpenTofu arguments after `--`:

```sh
task tf:proxmox-jarvis-plan -- -out=review.tfplan
task tf:proxmox-jarvis-apply -- review.tfplan
task tf:rustfs-gen8-output -- -json bucket_quotas
```

Get owner approval before plans, applies, and other host contact.
Plan and apply require the root's local tfvars. Both use `-input=false`.
Output reads saved state without refreshing the API. It needs the state
credentials but doesn't require the root's connection tfvars.
Raw key outputs are secret.

Private runners share execution and preconditions. Only the OVH bootstrap
runner loads the OVH account credential. RustFS commands unset ambient
`RUSTFS_ENDPOINT`, `RUSTFS_USER`, and `RUSTFS_SECRET` so tfvars select the target.

The `bootstrap-*`, `pve-jarvis-*`, and `jarvis-*` names remain aliases.
Use `task tf:ovh-bootstrap-state-list` to inspect the backend bootstrap state.

## Capacity units

Configuration follows each provider's native units. Don't convert existing
inputs or round disk sizes to change their display.

| Input | Unit |
| --- | --- |
| Proxmox root disks and VM disk sizes | GiB |
| Proxmox mount point sizes | Native suffixed values, such as `10G` |
| Proxmox memory | MiB |
| TrueNAS dataset quotas and reservations | Bytes |
| TrueNAS SMB auto and Time Machine quotas | GiB |
| RustFS `quota_gib` | GiB, converted to bytes by the bucket module |

Human-readable capacity summaries use decimal GB: one GB is 1,000,000,000 bytes.
One GiB is 1,073,741,824 bytes. A 64 GiB disk therefore reads as 68.72 GB.
Numeric capacity outputs keep exact bytes for scripts. Missing measurements
stay unknown rather than becoming zero.

The [National Institute of Standards and Technology](https://physics.nist.gov/cuu/Units/binary.html)
defines GB and GiB separately.
[Prometheus naming guidance](https://prometheus.io/docs/practices/naming/)
uses bytes as the base unit for measurements.

## VM image sources

| Input | Use case | Image owner | Disk import |
| --- | --- | --- | --- |
| `vm_image_downloads` | Install from a published, versioned `.qcow2.xz` archive. Pin its URL and SHA256. PVE downloads and decompresses it into `iso` storage. | OpenTofu | `disk.file_id`, over SSH |
| `vm_image_files`, `content_type = "iso"` | Reuse an existing `.qcow2.img` in `iso` storage, such as a file retained after a transfer of ownership. | Operator or another tool | `disk.file_id`, over SSH |
| `vm_image_files`, `content_type = "import"` | Use a verified, decompressed `.qcow2` already available in Import storage. A separate tool can publish it. | Operator or another tool | `disk.import_from`, through the PVE API |

The download itself uses the PVE API. For an `iso` volume, bpg connects to the
hypervisor over SSH to import and attach the disk. With an `import` volume, PVE
performs the import through its API. The API token and SSH key are separate
credentials. See the [bpg compressed-image guide](https://github.com/bpg/terraform-provider-proxmox/blob/v0.116.0/docs/guides/cloud-image.md#create-a-vm-from-a-compressed-cloud-image).

Set `pve_ssh_username` and use a dedicated SSH agent key when an import needs
SSH. Keep the private key out of tfvars. Leave `pve_ssh_username` unset on
roots that only use the API. An SSH login with broad privileges isn't limited
by the API token's permissions.

Use one image map per label. Removing a VM doesn't remove a managed image.
Removing its download pin schedules file deletion. Before switching a managed
file to `vm_image_files`, follow [the image retention runbook](../docs/runbooks/retain-pve-vm-image.md).
A lookup or adoption by filename doesn't verify the existing bytes.

Keep one workload root per PVE node for this workflow. A state split doesn't
restrict SSH access on the hypervisor. Scope the key to the runs that need it.
Split roots only when different operators, credentials, or apply schedules
need separate control. See [root layout rules](BACKEND.md#root-layout-rules).

## Example: Home Assistant OS on Jarvis

Use the [Proxmox VM runbook](../docs/runbooks/provision-pve-vm.md) and the
[Jarvis workload examples](proxmox/jarvis/jarvis.local.auto.tfvars.example).
For a fresh Jarvis state with only Home Assistant, set `lxc_workloads = {}`
and declare one VM. Don't use that configuration against the existing Jarvis
state, which also manages an LXC workload.

For a fresh install, use the managed `vm_image_downloads` example. PVE
verifies and decompresses the archive on a new download. If the plan adopts
an existing file by name, verify its contents independently before approval.
Set `pve_ssh_username`
and load the dedicated key into `ssh-agent` for the disk import. Verify the
node's host key first. This path needs no local copy or image mirror.
Leave the existing image reference unchanged when keeping a running VM.

Before replacing an existing instance, verify its backup and encryption key
outside Jarvis. Restore the backup only after separate approval. Upgrade Home
Assistant OS from Home Assistant, not by changing the image pin.

## VM hardware settings

Each `vm_workloads` entry accepts typed settings with these defaults:

| Setting | Default |
| --- | --- |
| `cpu` | 2 cores, 1 socket, `qemu64`, no hotplugged count, `numa = false` |
| `memory` | `dedicated = 4096`, `floating = 0`, `shared = 0`, in mebibytes |
| `disk` | `size = 64` gibibytes, `interface = "scsi0"`, on the node storage |
| `agent` | Enabled, `virtio`, `timeout = "15m"`, `trim = false` |
| `network_devices` | One `virtio` device on the node bridge |
| `vga` | `null`, no explicit display block |
| `timeouts` | Provider defaults: 1800 seconds per operation, 300 for `stop_vm` |
| `bios` | `"ovmf"` |
| `machine` | `null`, provider default |
| `boot_order` | The selected `disk.interface` |
| `scsi_hardware` | `"virtio-scsi-single"` |
| `hotplug` | `["disk", "network", "usb"]` |
| `os_type` | `"l26"` |
| `reboot_after_update` | `true` |
| `efi_disk` | Enabled, `4m`, no pre-enrolled keys, on the node storage |

Omitted, empty, or null setting objects retain defaults, except `vga`.
A null `vga` leaves that block unset. An empty `vga` selects `std` with 16 mebibytes.
A null `boot_order` selects the imported disk.

- `cpu` accepts `cores`, `sockets`, `type`, `hotplugged`, and `numa`.
  CPU models and versioned machine names use provider validation rather than local allowlists.
- `memory.floating = 0` disables ballooning. Other values set its minimum, up to `dedicated`.
- `disk` and `additional_disks` accept `file_format`, `cache`, `backup`, `discard`, `iothread`, `ssd`, and `queues`.
  Omitted tuning retains provider defaults. Queues require a `scsi` interface and `virtio-scsi-single`.
  Additional disks must use unique interfaces outside the selected boot slot.
- `agent` also accepts an optional `wait_for_ip` object with `disabled`, `ipv4`, and `ipv6`.
  An omitted object retains provider wait behavior.
- `network_devices` accepts 1 to 32 ordered devices.
  Each accepts `bridge`, `model`, `vlan_id`, `mac_address`, `firewall`, `disconnected`, `queues`, `mtu`, and `rate_limit`.
  A null bridge uses the node bridge. Device order determines interface indexes.
- `efi_disk` accepts `enabled`, `datastore_id`, `file_format`, `type`, and `pre_enrolled_keys`.
  Setting `enabled = false` omits that disk, for example with SeaBIOS.
- `timeouts` accepts `create`, `migrate`, `reboot`, `shutdown_vm`, `start_vm`, and `stop_vm`, in seconds.
  The module doesn't expose clone or deprecated disk-move timeouts.

Closed string choices follow the
[pinned provider values](https://github.com/bpg/terraform-provider-proxmox/blob/v0.116.0/docs/resources/virtual_environment_vm.md).
The hardware families also appear in
[trfore's VM modules](https://github.com/trfore/terraform-bpg-proxmox/tree/b4bf9fb524ddcbd0c79afc2cb9a759de70bb3f9e/modules).
LXC OS and console types retain their own allowlists.

The `hotplug` set accepts `disk`, `network`, `usb`, `cpu`, and `memory`.
An empty set disables hotplug. Memory hotplug requires `cpu.numa = true`.
The guest must support the selected features.
Only `cpu.hotplugged` controls the active processor count.
Changing `cpu.cores` or `cpu.sockets` can require a restart.
A memory decrease can fail before the provider restarts the VM.
An approved full stop before the decrease avoids guest memory-unplug failures.

## Workload deletion protection

VM workloads expose two independent settings in `vm_workloads`:

| Setting | Default | Effect |
| --- | --- | --- |
| `protection` | `true` | Proxmox blocks deletion of the VM and its disks |
| `prevent_destroy` | `true` | OpenTofu rejects plans that destroy or replace the VM |

Omitted or null values retain these defaults.
A deliberate replacement requires both settings to be `false`.
Proxmox protection must be disabled by an apply before planning the replacement.
Removing a workload entry also removes its lifecycle guard from the configuration.
Proxmox protection remains active until explicitly disabled.
These guards don't replace backups.

LXC workloads expose only `protection`, with a default of `false`.
The LXC module doesn't set `prevent_destroy`.

## Local tests

Run `task tf:test` for mocked LXC and VM module tests.
After `task tf:init`, run `task tf:test-root-inputs` for the Jarvis input contract.
Run `task tf:test-pve-bootstrap` to check the clean-node access path.
Run `task tf:test-truenas` for the Gen8 pool, identity, and export contracts.
Run `task tf:test-rustfs` for the catalog and Gen8 connection contracts.
These tests run in `task verify` and use fixtures without host contact or
connection credentials. Provider installation can need registry access.
Successful root plans target local inventory because datastore outputs aren't
mockable. They don't qualify live node or VM behavior.
Module lock files are ignored. Root lock files are tracked.

## Editor setup

These files are OpenTofu. The HashiCorp Terraform language server
rejects valid OpenTofu blocks such as `encryption` with
`Blocks of type ... are not expected here`. Use the OpenTofu extension
([vscode-opentofu](https://marketplace.visualstudio.com/items?itemName=OpenTofu.vscode-opentofu))
version 0.6.3 or newer. Older versions bundle a language server whose
schema doesn't know the `encryption` block, and raises the same false
error. Linting runs through `task tf:lint` with the repository
`terraform/.tflint.hcl`.
