variable "node" {
  description = "PVE node that runs the VM."
  type        = string
}

variable "storage" {
  description = "Node storage for the boot and EFI disks."
  type        = string
}

variable "bridge" {
  description = "Node bridge for the VM network device."
  type        = string
}

variable "id" {
  description = "VM ID, unique across the node."
  type        = number

  validation {
    condition     = var.id == floor(var.id) && var.id >= 1000 && var.id <= 999999999
    error_message = "id must be an integer from 1000 to 999999999."
  }
}

variable "name" {
  description = "VM name in the node UI."
  type        = string
}

variable "bios" {
  description = "VM firmware implementation."
  type        = string
  default     = "ovmf"
  nullable    = false

  validation {
    condition     = contains(["ovmf", "seabios"], var.bios)
    error_message = "bios must be ovmf or seabios."
  }
}

variable "boot_order" {
  description = "Ordered boot devices. Null boots from disk.interface."
  type        = list(string)
  default     = null
}

variable "machine" {
  description = "Machine type or versioned machine name. Null keeps the provider default."
  type        = string
  default     = null
}

variable "reboot_after_update" {
  description = "Allow the provider to reboot the VM for changes that require it."
  type        = bool
  default     = true
  nullable    = false

}

variable "scsi_hardware" {
  description = "VM SCSI controller model."
  type        = string
  default     = "virtio-scsi-single"
  nullable    = false

  validation {
    condition = contains([
      "lsi", "lsi53c810", "virtio-scsi-pci", "virtio-scsi-single", "megasas", "pvscsi",
    ], var.scsi_hardware)
    error_message = "scsi_hardware must be lsi, lsi53c810, virtio-scsi-pci, virtio-scsi-single, megasas, or pvscsi."
  }
}

variable "hotplug" {
  description = "Hotplug features. An empty set disables hotplug. Memory requires cpu.numa."
  type        = set(string)
  default     = ["disk", "network", "usb"]
  nullable    = false

  validation {
    condition = alltrue([
      for feature in var.hotplug :
      feature != null ? contains(["cpu", "disk", "memory", "network", "usb"], feature) : false
    ])
    error_message = "hotplug accepts only cpu, disk, memory, network, and usb. Use an empty set to disable hotplug."
  }

  validation {
    condition     = !contains(var.hotplug, "memory") || var.cpu.numa
    error_message = "Memory hotplug requires cpu.numa = true."
  }
}

variable "cpu" {
  description = "CPU topology and model. Hotplugged is the active processor count, not the core count."
  type = object({
    cores      = optional(number, 2)
    sockets    = optional(number, 1)
    type       = optional(string, "qemu64")
    hotplugged = optional(number, 0)
    numa       = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition = (
      var.cpu.cores == floor(var.cpu.cores) && var.cpu.cores >= 1 && var.cpu.cores <= 128 &&
      var.cpu.sockets == floor(var.cpu.sockets) && var.cpu.sockets >= 1 && var.cpu.sockets <= 16 &&
      var.cpu.hotplugged == floor(var.cpu.hotplugged) &&
      var.cpu.hotplugged >= 0 && var.cpu.hotplugged <= min(2304, var.cpu.cores * var.cpu.sockets)
    )
    error_message = "CPU cores must be 1..128, sockets 1..16, and hotplugged 0..min(2304, cores*sockets), all integers."
  }
}

variable "memory" {
  description = "Memory sizes in mebibytes. Floating zero disables ballooning."
  type = object({
    dedicated = optional(number, 4096)
    floating  = optional(number, 0)
    shared    = optional(number, 0)
  })
  default  = {}
  nullable = false

  validation {
    condition = (
      var.memory.dedicated == floor(var.memory.dedicated) && var.memory.dedicated >= 2048 &&
      var.memory.floating == floor(var.memory.floating) && var.memory.floating >= 0 &&
      var.memory.floating <= var.memory.dedicated &&
      var.memory.shared == floor(var.memory.shared) && var.memory.shared >= 0
    )
    error_message = "Memory values must be integer mebibytes: dedicated >= 2048, floating 0..dedicated, and shared >= 0."
  }
}

variable "disk" {
  description = "Imported boot disk settings. Omitted tuning uses provider defaults."
  type = object({
    size         = optional(number, 64)
    interface    = optional(string, "scsi0")
    datastore_id = optional(string)
    file_format  = optional(string)
    cache        = optional(string)
    backup       = optional(bool, true)
    discard      = optional(string)
    iothread     = optional(bool)
    ssd          = optional(bool)
    queues       = optional(number)
  })
  default  = {}
  nullable = false

  validation {
    condition = (
      var.disk.size == floor(var.disk.size) && var.disk.size >= 32 &&
      can(regex("^(scsi([0-9]|[12][0-9]|30)|sata[0-5]|virtio([0-9]|1[0-5]))$", var.disk.interface)) &&
      (var.disk.file_format == null ? true : contains(["raw", "qcow2", "vmdk"], var.disk.file_format)) &&
      (var.disk.cache == null ? true : contains(["none", "directsync", "writethrough", "writeback", "unsafe"], var.disk.cache)) &&
      (var.disk.discard == null ? true : contains(["on", "ignore"], var.disk.discard)) &&
      (var.disk.ssd != true || !startswith(var.disk.interface, "virtio")) &&
      (var.disk.queues == null ? true : (
        var.disk.queues == floor(var.disk.queues) && var.disk.queues >= 2 &&
        startswith(var.disk.interface, "scsi") && var.scsi_hardware == "virtio-scsi-single"
      ))
    )
    error_message = "The boot disk needs an integer size >= 32, a supported interface and tuning, and queues only on virtio-scsi-single. VirtIO block disks can't use SSD emulation."
  }
}

variable "agent" {
  description = "QEMU guest agent settings. Null wait_for_ip keeps provider wait behavior."
  type = object({
    enabled = optional(bool, true)
    type    = optional(string, "virtio")
    timeout = optional(string, "15m")
    trim    = optional(bool, false)
    wait_for_ip = optional(object({
      disabled = optional(bool, false)
      ipv4     = optional(bool, false)
      ipv6     = optional(bool, false)
    }))
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["isa", "virtio"], var.agent.type)
    error_message = "agent.type must be isa or virtio."
  }
}

variable "efi_disk" {
  description = "Persistent UEFI disk settings. Disable for firmware that doesn't need this disk."
  type = object({
    enabled           = optional(bool, true)
    datastore_id      = optional(string)
    file_format       = optional(string)
    type              = optional(string, "4m")
    pre_enrolled_keys = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition = (
      contains(["2m", "4m"], lower(var.efi_disk.type)) &&
      (var.efi_disk.file_format == null ? true : contains(["raw", "qcow2", "vmdk"], var.efi_disk.file_format))
    )
    error_message = "efi_disk.type must be 2m or 4m, and file_format must be raw, qcow2, or vmdk when set."
  }
}

variable "network_devices" {
  description = "Ordered network devices. A null bridge uses the node bridge."
  type = list(object({
    bridge       = optional(string)
    model        = optional(string, "virtio")
    vlan_id      = optional(number)
    mac_address  = optional(string)
    firewall     = optional(bool, false)
    disconnected = optional(bool, false)
    queues       = optional(number)
    mtu          = optional(number)
    rate_limit   = optional(number)
  }))
  default  = [{}]
  nullable = false

  validation {
    condition = length(var.network_devices) >= 1 && length(var.network_devices) <= 32 && alltrue([
      for device in var.network_devices : device == null ? false : (
        contains(["e1000", "e1000e", "rtl8139", "virtio", "vmxnet3"], device.model) &&
        (device.vlan_id == null ? true : device.vlan_id == floor(device.vlan_id) && device.vlan_id >= 1 && device.vlan_id <= 4094) &&
        (device.queues == null ? true : device.queues == floor(device.queues) && device.queues >= 0 && device.queues <= 64) &&
        (device.mtu == null ? true : device.mtu == floor(device.mtu) && device.mtu >= 1) &&
        (device.rate_limit == null ? true : device.rate_limit >= 0)
      )
    ])
    error_message = "network_devices needs 1..32 devices with supported models, VLANs 1..4094, queues 0..64, positive integer MTUs, and nonnegative rates."
  }
}

variable "vga" {
  description = "Optional display settings. Null leaves the display block unset."
  type = object({
    type   = optional(string, "std")
    memory = optional(number, 16)
  })
  default = null

  validation {
    condition = var.vga == null ? true : (
      contains(["cirrus", "none", "qxl", "qxl2", "qxl3", "qxl4", "serial0", "serial1", "serial2", "serial3", "std", "virtio", "virtio-gl", "vmware"], var.vga.type) &&
      var.vga.memory == floor(var.vga.memory) && var.vga.memory >= 4 && var.vga.memory <= 512
    )
    error_message = "vga needs a supported display type and integer memory from 4 to 512 mebibytes."
  }
}

variable "timeouts" {
  description = "Operation timeouts in seconds, with defaults matching the pinned provider."
  type = object({
    create      = optional(number, 1800)
    migrate     = optional(number, 1800)
    reboot      = optional(number, 1800)
    shutdown_vm = optional(number, 1800)
    start_vm    = optional(number, 1800)
    stop_vm     = optional(number, 300)
  })
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for timeout in var.timeouts : timeout == floor(timeout) && timeout > 0
    ])
    error_message = "Operation timeouts must be positive integer seconds when set."
  }
}

variable "os_type" {
  description = "Guest operating system type."
  type        = string
  default     = "l26"
  nullable    = false

  validation {
    condition = contains([
      "l24", "l26", "other", "solaris", "w2k", "w2k3", "w2k8",
      "win7", "win8", "win10", "win11", "wvista", "wxp",
    ], var.os_type)
    error_message = "os_type must be l24, l26, other, solaris, w2k, w2k3, w2k8, win7, win8, win10, win11, wvista, or wxp."
  }
}

variable "image_file_id" {
  description = "Decompressed QCOW2 image ID in ISO content, imported through provider SSH."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+:iso/[A-Za-z0-9_.-]+[.]qcow2[.]img$", var.image_file_id))
    error_message = "image_file_id must identify a decompressed datastore:iso/name.qcow2.img image."
  }
}

variable "additional_disks" {
  description = "Optional data disks attached after the imported boot disk."
  type = list(object({
    interface    = string
    datastore_id = optional(string)
    size         = optional(number)
    file_id      = optional(string)
    import_from  = optional(string)
    file_format  = optional(string)
    cache        = optional(string)
    backup       = optional(bool, true)
    discard      = optional(string, "ignore")
    iothread     = optional(bool, false)
    ssd          = optional(bool)
    queues       = optional(number)
  }))
  default  = []
  nullable = false

  validation {
    condition = alltrue([
      for disk in var.additional_disks :
      can(regex("^(scsi([0-9]|[12][0-9]|30)|sata[0-5]|virtio([0-9]|1[0-5]))$", disk.interface)) &&
      disk.interface != var.disk.interface &&
      (
        (disk.size != null ? 1 : 0) +
        (disk.file_id != null ? 1 : 0) +
        (disk.import_from != null ? 1 : 0)
      ) == 1 &&
      (disk.size == null || (disk.size == floor(disk.size) && disk.size >= 1)) &&
      (disk.file_format == null ? true : contains(["raw", "qcow2", "vmdk"], disk.file_format)) &&
      (disk.cache == null ? true : contains(["none", "directsync", "writethrough", "writeback", "unsafe"], disk.cache)) &&
      contains(["on", "ignore"], disk.discard) &&
      (disk.ssd != true || !startswith(disk.interface, "virtio")) &&
      (disk.queues == null ? true : (
        disk.queues == floor(disk.queues) && disk.queues >= 2 &&
        startswith(disk.interface, "scsi") && var.scsi_hardware == "virtio-scsi-single"
      ))
    ]) && length(distinct([for disk in var.additional_disks : disk.interface])) == length(var.additional_disks)
    error_message = "Additional disks need unique supported interfaces outside the boot slot, one size or image source, and valid tuning. Queues require virtio-scsi-single."
  }
}

variable "description" {
  description = "Provenance note in the node UI."
  type        = string
  default     = "Managed by Terraform (homelab-ops)"
  nullable    = false
}

variable "tags" {
  description = "VM tags."
  type        = list(string)
  default     = ["terraform"]
  nullable    = false
}

variable "protection" {
  description = "PVE deletion protection. Apply false before a deliberate replacement or removal."
  type        = bool
  default     = true
  nullable    = false
}

variable "prevent_destroy" {
  description = "Reject plans that destroy or replace the VM. Set false for a deliberate replacement or removal."
  type        = bool
  default     = true
  nullable    = false
}

variable "started" {
  description = "Start the VM after creation."
  type        = bool
  default     = true
  nullable    = false
}

variable "start_on_boot" {
  description = "Start the VM when the node boots."
  type        = bool
  default     = true
  nullable    = false
}

variable "startup" {
  description = "Boot order and delays. Null uses node defaults."
  type = object({
    order      = number
    up_delay   = optional(number)
    down_delay = optional(number)
  })
  default = null
}
