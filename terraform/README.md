# terraform/

Infrastructure as code for Proxmox VE and TrueNAS, on OpenTofu.

The tree groups by provider category. A category holds one root per
target.

- `proxmox/` holds one root per PVE server, plus `proxmox/modules/` for
  what those roots share. The PVE resources use the
  [bpg provider](https://github.com/bpg/terraform-provider-proxmox).
  `proxmox/jarvis/` owns LXC workloads and optional imported-image VMs through
  separate maps in its git-ignored tfvars. An apply writes an Ansible inventory
  fragment for each LXC workload:
  `ansible/inventory/servers/iac.tf.<node>.yml`. Each LXC workload joins
  `grp_servers_immutable` through a `grp_servers_immutable_<host>` leaf. The leaf
  repeats its parent's name and replaces hyphens with underscores. The fragment
  includes the LXC hostname and container ID, but no address.
  A later PVE server gets its own root, named after it.
- `proxmox/modules/lxc/` wraps one LXC workload: a golden image clone,
  started, addressed by DHCP unless the caller pins a static address from its
  git-ignored tfvars. Node facts live in the calling root, in its `locals.tf`.
- `proxmox/modules/vm/` wraps one VM booted from an imported QCOW2 image.
  The Jarvis root owns server-side downloads and keeps VM workloads out of Linux Ansible.
  A declared download pin owns its source image. Removing a workload leaves the
  image. Removing the pin deletes it. Existing managed images enter state
  through conditional imports. `vm_image_files` reads existing files without
  taking ownership. Downloads use the API. VM disk imports use SSH with an
  agent key.
- `truenas/` imports datasets, NFS shares, and snapshots. Everything that
  democratic-csi creates stays out of Terraform management.
  Planned. The directory doesn't exist yet.
- `talos-lab/` holds discovery VMs only. Production Talos nodes are
  bare metal and stay outside Terraform. Planned.
- `bootstrap/` mints credentials and stays frozen. `bootstrap/ovh/` owns the
  state backend, and is the only root with a local state. `bootstrap/pve/<node>/`
  owns one PVE node's Terraform access chain.

State lives in the OVH S3 backend, never in git. Read `BACKEND.md`
before the first stateful run.

## Root rules

One root covers one provider, one blast radius, and one apply cadence.
Don't split roots by resource type. `bootstrap/ovh/` stays frozen and owns
only the state backend. Every root declares its own state key in its
`backend.tf`, mirroring its path under `terraform/`: the `proxmox/jarvis`
root stores at `proxmox/jarvis/terraform.tfstate`.
Moving a root directory doesn't move its remote state.
Keep the existing backend key during a code move, or review a separate state migration.
See [State locations and code moves](BACKEND.md#state-locations-and-code-moves) for the rules.

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

### VM input migration

VM settings use objects rather than the scalar fields below.
LXC inputs don't change. Existing resource addresses and image ownership don't change.

| Old setting | Object field |
| --- | --- |
| `cpu = 4` | `cpu = { cores = 4 }` |
| `ram = 8192` | `memory = { dedicated = 8192 }` |
| `disk = 128` | `disk = { size = 128 }` |
| `numa` | `cpu.numa` |
| `boot_disk_interface` | `disk.interface` |
| `agent_enabled` | `agent.enabled` |
| `network_model` | `network_devices[0].model` |
| `vlan_id` | `network_devices[0].vlan_id` |
| `mac_address` | `network_devices[0].mac_address` |

The root rejects old named settings rather than silently dropping them during object conversion.
Scalar `cpu` and `disk` values fail type validation.
Adapt the private tfvars using the
[tracked example](proxmox/jarvis/jarvis.local.auto.tfvars.example) before the next approved plan.
The new inputs don't authorize host contact or a state migration.

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

Run `task tf:test` for the LXC and VM module tests.
The task uses OpenTofu mock providers, without root connection variables or host contact.
Provider installation can require registry access.
After `task tf:init`, run `task tf:test-root-inputs` for the Jarvis input contract and migration guards.
These tests use fixtures rather than connection credentials.
Successful input plans target the local inventory because the provider's datastore outputs aren't mockable.
They don't qualify node checks or live VM changes.
`task verify` includes both test suites.
Generated module lock files stay local. Root lock files remain tracked.

## Editor setup

These files are OpenTofu. The HashiCorp Terraform language server
rejects valid OpenTofu blocks such as `encryption` with
`Blocks of type ... are not expected here`. Use the OpenTofu extension
([vscode-opentofu](https://marketplace.visualstudio.com/items?itemName=OpenTofu.vscode-opentofu))
version 0.6.3 or newer. Older versions bundle a language server whose
schema doesn't know the `encryption` block, and raises the same false
error. Linting runs through `task tf:lint` with the repository
`terraform/.tflint.hcl`.
