variable "state_passphrase" {
  description = "Passphrase for the state encryption. Source: TF_VAR_state_passphrase in .env.tf."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must hold at least 16 characters."
  }
}

variable "pve_endpoint" {
  description = "PVE API endpoint of this node. Source: jarvis.local.auto.tfvars, git-ignored."
  type        = string
}

variable "pve_api_token" {
  description = "PVE API token of this node. Source: jarvis.local.auto.tfvars, git-ignored."
  type        = string
  sensitive   = true
}

variable "pve_ssh_username" {
  description = "Node SSH login for VM disk import through ssh-agent. Null disables SSH configuration."
  type        = string
  default     = null

  validation {
    condition     = var.pve_ssh_username == null ? true : length(trimspace(var.pve_ssh_username)) > 0
    error_message = "pve_ssh_username must be null or a nonempty SSH login."
  }
}

variable "lxc_workloads" {
  description = "One LXC workload per entry, keyed by hostname. The type mirrors modules/lxc, node, storage, and bridge excepted: they're node facts. The defaults are the module's own, so an entry names only what it changes. Source: jarvis.local.auto.tfvars, git-ignored."
  type = map(object({
    id          = number
    template    = string
    description = optional(string, "Managed by Terraform (homelab-ops)")
    tags        = optional(list(string), ["terraform"])
    protection  = optional(bool, false)
    os_type     = optional(string, "debian")
    disk        = optional(number, 8)
    mountpoints = optional(list(object({
      volume    = string
      path      = string
      size      = optional(string)
      backup    = optional(bool, false)
      read_only = optional(bool, false)
    })))
    cpu            = optional(number, 1)
    ram            = optional(number, 1024)
    swap           = optional(number, 512)
    interface_name = optional(string, "eth0")
    vlan_id        = optional(number)
    mac_address    = optional(string)
    ipv4 = optional(object({
      address = optional(string, "dhcp")
      gateway = optional(string)
    }))
    started       = optional(bool, true)
    start_on_boot = optional(bool, true)
    console_type  = optional(string, "shell")
    startup = optional(object({
      order      = number
      up_delay   = optional(number)
      down_delay = optional(number)
    }))
    unprivileged = optional(bool, true)
    # Nesting is the one feature flag an API token may set; keyctl is
    # root@pam-only in PVE. The golden images carry Docker, so nesting is the
    # one default this type changes.
    nesting       = optional(bool, true)
    keyctl        = optional(bool, false)
    wait_for_ipv4 = optional(bool, true)
  }))
}

variable "vm_image_downloads" {
  description = "Versioned VM images downloaded and managed by Terraform, keyed by image label."
  type = map(object({
    url       = string
    sha256    = string
    file_name = string
    storage   = string
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for image in values(var.vm_image_downloads) :
      can(regex("^https://[^[:space:]]+[.]qcow2[.]xz$", image.url)) &&
      can(regex("^[0-9a-fA-F]{64}$", image.sha256)) &&
      can(regex("^[A-Za-z0-9_.-]+-[0-9]+[.][0-9]+([.][0-9]+)?[.]qcow2[.]img$", image.file_name))
    ])
    error_message = "Downloads require an HTTPS QCOW2.XZ URL, a 64-character SHA256, and a versioned QCOW2.IMG filename."
  }
}

variable "vm_image_files" {
  description = "Existing VM images managed outside Terraform, keyed by image label."
  type = map(object({
    file_name = string
    storage   = string
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for image in values(var.vm_image_files) :
      can(regex("^[A-Za-z0-9_.-]+-[0-9]+[.][0-9]+([.][0-9]+)?[.]qcow2[.]img$", image.file_name))
    ])
    error_message = "Existing VM image files require a versioned QCOW2.IMG filename."
  }
}

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
    condition = alltrue([
      for workload in values(var.vm_workloads) :
      workload.ram == null && workload.numa == null && workload.boot_disk_interface == null &&
      workload.agent_enabled == null && workload.network_model == null &&
      workload.vlan_id == null && workload.mac_address == null
    ])
    error_message = "Migrate VM scalar settings to cpu, memory, disk, agent, and network_devices objects. Remove ram, numa, boot_disk_interface, agent_enabled, network_model, vlan_id, and mac_address."
  }
}
