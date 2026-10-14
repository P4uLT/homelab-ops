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
    backup       = optional(bool, true)
    discard      = optional(string, "ignore")
    iothread     = optional(bool, false)
    queues       = optional(number)
  }))
  default  = []
  nullable = false

  validation {
    condition = alltrue([
      for disk in var.additional_disks :
      can(regex("^(scsi|sata|virtio)[1-9][0-9]*$", disk.interface)) &&
      (
        (disk.size != null ? 1 : 0) +
        (disk.file_id != null ? 1 : 0) +
        (disk.import_from != null ? 1 : 0)
      ) == 1 &&
      (disk.size == null || (disk.size == floor(disk.size) && disk.size >= 1)) &&
      contains(["on", "ignore"], disk.discard) &&
      (disk.queues == null || (disk.queues == floor(disk.queues) && disk.queues >= 2))
    ]) && length(distinct([for disk in var.additional_disks : disk.interface])) == length(var.additional_disks)
    error_message = "Additional disks need unique scsi1+, sata1+, or virtio1+ interfaces, exactly one size or image source, valid discard and queue settings, and a positive integer size for new disks."
  }
}

variable "cpu" {
  description = "Assigned CPU cores."
  type        = number
  default     = 2
  nullable    = false

  validation {
    condition     = var.cpu == floor(var.cpu) && var.cpu >= 1 && var.cpu <= 128
    error_message = "cpu must be an integer from 1 to 128."
  }
}

variable "ram" {
  description = "Dedicated memory, in mebibytes."
  type        = number
  default     = 4096
  nullable    = false

  validation {
    condition     = var.ram == floor(var.ram) && var.ram >= 2048
    error_message = "ram must be an integer of at least 2048 mebibytes."
  }
}

variable "disk" {
  description = "Boot disk size, in gibibytes."
  type        = number
  default     = 64
  nullable    = false

  validation {
    condition     = var.disk == floor(var.disk) && var.disk >= 32
    error_message = "disk must be an integer of at least 32 gibibytes."
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

variable "vlan_id" {
  description = "Network VLAN tag. Null uses the bridge default."
  type        = number
  default     = null

  validation {
    condition     = var.vlan_id == null ? true : var.vlan_id == floor(var.vlan_id) && var.vlan_id >= 1 && var.vlan_id <= 4094
    error_message = "vlan_id must be null or an integer from 1 to 4094."
  }
}

variable "mac_address" {
  description = "Stable MAC for a DHCP reservation. Null lets PVE assign one."
  type        = string
  default     = null
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
