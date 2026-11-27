variable "vm_workloads" {
  description = "Imported-image VMs, keyed by VM name. Source: jarvis.local.auto.tfvars, git-ignored."
  type = map(object({
    id                  = number
    image               = string
    bios                = optional(string, "ovmf")
    machine             = optional(string)
    boot_order          = optional(list(string))
    scsi_hardware       = optional(string, "virtio-scsi-single")
    hotplug             = optional(set(string), ["disk", "network", "usb"])
    reboot_after_update = optional(bool, true)
    cpu = optional(object({
      cores      = optional(number, 2)
      sockets    = optional(number, 1)
      type       = optional(string, "qemu64")
      hotplugged = optional(number, 0)
      numa       = optional(bool, false)
    }), {})
    memory = optional(object({
      dedicated = optional(number, 4096)
      floating  = optional(number, 0)
      shared    = optional(number, 0)
    }), {})
    disk = optional(object({
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
    }), {})
    agent = optional(object({
      enabled = optional(bool, true)
      type    = optional(string, "virtio")
      timeout = optional(string, "15m")
      trim    = optional(bool, false)
      wait_for_ip = optional(object({
        disabled = optional(bool, false)
        ipv4     = optional(bool, false)
        ipv6     = optional(bool, false)
      }))
    }), {})
    efi_disk = optional(object({
      enabled           = optional(bool, true)
      datastore_id      = optional(string)
      file_format       = optional(string)
      type              = optional(string, "4m")
      pre_enrolled_keys = optional(bool, false)
    }), {})
    network_devices = optional(list(object({
      bridge       = optional(string)
      model        = optional(string, "virtio")
      vlan_id      = optional(number)
      mac_address  = optional(string)
      firewall     = optional(bool, false)
      disconnected = optional(bool, false)
      queues       = optional(number)
      mtu          = optional(number)
      rate_limit   = optional(number)
    })), [{}])
    vga = optional(object({
      type   = optional(string, "std")
      memory = optional(number, 16)
    }))
    timeouts = optional(object({
      create      = optional(number, 1800)
      migrate     = optional(number, 1800)
      reboot      = optional(number, 1800)
      shutdown_vm = optional(number, 1800)
      start_vm    = optional(number, 1800)
      stop_vm     = optional(number, 300)
    }), {})
    protection      = optional(bool, true)
    prevent_destroy = optional(bool, true)
    description     = optional(string, "Managed by Terraform (homelab-ops)")
    tags            = optional(list(string), ["terraform"])
    os_type         = optional(string, "l26")
    started         = optional(bool, true)
    start_on_boot   = optional(bool, true)
    startup = optional(object({
      order      = number
      up_delay   = optional(number)
      down_delay = optional(number)
    }))
    additional_disks = optional(list(object({
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
    })), [])

    # Retain rejected fields so object conversion can't silently reset settings.
    ram                 = optional(number)
    numa                = optional(bool)
    boot_disk_interface = optional(string)
    agent_enabled       = optional(bool)
    network_model       = optional(string)
    vlan_id             = optional(number)
    mac_address         = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for workload in values(var.vm_workloads) :
      workload.id == floor(workload.id) && workload.id >= 1000 && workload.id <= 999999999
    ])
    error_message = "VM IDs must be integers from 1000 to 999999999."
  }

  validation {
    condition = var.pve_ssh_username != null || !anytrue([
      for workload in values(var.vm_workloads) :
      contains(keys(var.vm_image_downloads), workload.image) ||
      try(var.vm_image_files[workload.image].content_type == "iso", false) ||
      anytrue([for disk in workload.additional_disks : disk.file_id != null])
    ])
    error_message = "VM disks using file_id require pve_ssh_username and a loaded ssh-agent key."
  }

  validation {
    condition = alltrue([
      for workload in values(var.vm_workloads) :
      workload.ram == null && workload.numa == null && workload.boot_disk_interface == null &&
      workload.agent_enabled == null && workload.network_model == null &&
      workload.vlan_id == null && workload.mac_address == null
    ])
    error_message = "Migrate VM scalar settings to cpu, memory, disk, agent, and network_devices objects. Remove ram, numa, boot_disk_interface, agent_enabled, network_model, vlan_id, and mac_address."
  }
}
