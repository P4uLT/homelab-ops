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
  The Jarvis root manages API downloads and excludes VMs from Linux Ansible.
  Disk imports use SSH with an agent key. Conditional imports adopt managed
  images, while `vm_image_files` references existing files without managing them.
  Removing a workload preserves its image. Removing a download pin deletes that image.
- `bootstrap/`: frozen credential and backend roots. `bootstrap/ovh/` creates
  the state backend and uses local state. `bootstrap/pve/<node>/` creates a
  node's Terraform access chain.
- `truenas/` (planned) imports datasets, NFS shares, and snapshots, excluding
  resources created by democratic-csi. The directory doesn't exist yet.
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
Both are included in `task verify` and use fixtures without host contact or
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
