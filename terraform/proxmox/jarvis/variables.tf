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
      size      = optional(number)
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
