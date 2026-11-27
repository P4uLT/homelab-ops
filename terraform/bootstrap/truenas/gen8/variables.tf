variable "state_passphrase" {
  description = "Passphrase from TF_VAR_state_passphrase."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must hold at least 16 characters."
  }
}

variable "truenas_host" {
  description = "TrueNAS management hostname or address, with an optional port."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([A-Za-z0-9][A-Za-z0-9.-]*|\\[[0-9A-Fa-f:]+\\])(:[0-9]+)?$", var.truenas_host))
    error_message = "Use a hostname or address without a scheme or path. Enclose IPv6 addresses in brackets."
  }
}

variable "truenas_api_key" {
  description = "TrueNAS API key for this root."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "truenas_ca_cert" {
  description = "Path to a PEM CA certificate for a private CA."
  type        = string
  default     = null
}

variable "pool" {
  description = "Data pool to create: name, single-vdev layout, and disk serials."
  type = object({
    name    = optional(string, "tank")
    layout  = optional(string, "RAIDZ2")
    serials = list(string)
  })
  nullable = false

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_.-]*$", var.pool.name))
    error_message = "Start the pool name with a letter, then use letters, digits, dots, dashes, or underscores."
  }

  validation {
    condition     = contains(["MIRROR", "RAIDZ", "RAIDZ2"], var.pool.layout)
    error_message = "Use MIRROR, RAIDZ, or RAIDZ2 for the pool layout."
  }

  validation {
    condition = try(
      length(var.pool.serials) >= (
        var.pool.layout == "MIRROR" ? 2 : var.pool.layout == "RAIDZ" ? 3 : 4
      ) &&
      length(toset([for serial in var.pool.serials : upper(serial)])) == length(var.pool.serials) &&
      alltrue([for serial in var.pool.serials : can(regex("^[^/[:space:]]+$", serial))]),
      false
    )
    error_message = "Supply distinct non-empty disk serials, not device paths. MIRROR needs two, RAIDZ three, RAIDZ2 four."
  }
}

variable "services" {
  description = "Whether to start each file service now and at boot. cifs is SMB."
  type = object({
    nfs  = bool
    cifs = bool
  })
  default  = { nfs = true, cifs = true }
  nullable = false

  validation {
    condition     = alltrue([for enabled in var.services : enabled != null])
    error_message = "Set each file service to true or false."
  }
}

variable "provision_smb_shares" {
  description = "Grant the provisioning identity permissions to manage SMB shares."
  type        = bool
  default     = false
  nullable    = false
}

variable "groups" {
  description = "Local groups to manage, keyed by stable labels."
  type = map(object({
    name = string
    gid  = optional(number)
    smb  = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition = try(
      length(toset([for group in var.groups : lower(group.name)])) == length(var.groups) &&
      alltrue([for group in var.groups : lower(group.name) != "terraform-prov"]),
      false
    )
    error_message = "Use distinct file group names. The provisioning group is managed separately."
  }
}

variable "users" {
  description = "Local users to manage, keyed by stable labels."
  type = map(object({
    username             = string
    full_name            = string
    uid                  = optional(number)
    email                = optional(string)
    home                 = optional(string)
    home_mode            = optional(string)
    shell                = optional(string)
    smb                  = optional(bool, false)
    locked               = optional(bool, false)
    ssh_password_enabled = optional(bool, false)
    sshpubkey            = optional(string)
    password_wo_version  = optional(number, 1)
    primary_group        = string
    additional_groups    = optional(set(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition = try(alltrue([
      for user in var.users :
      contains(keys(var.groups), user.primary_group) &&
      alltrue([for group in user.additional_groups : contains(keys(var.groups), group)])
    ]), false)
    error_message = "Reference group labels declared in groups."
  }

  validation {
    condition = try(
      length(toset([for user in var.users : lower(user.username)])) == length(var.users) &&
      alltrue([for user in var.users : lower(user.username) != "terraform-prov"]),
      false
    )
    error_message = "Use distinct file usernames. The provisioning account is managed separately."
  }
}

variable "provision_group_lookup" {
  description = "Grant account read access for named identities in dataset ACLs and NFS mappings."
  type        = bool
  default     = false
  nullable    = false
}

variable "provision_dataset_acls" {
  description = "Grant the storage identity filesystem ACL read and write access. TrueNAS doesn't scope these roles to a dataset."
  type        = bool
  default     = false
  nullable    = false
}

variable "provision_apps" {
  description = "Grant the provisioning identity the apps-subsystem roles."
  type        = bool
  default     = false
  nullable    = false
}

variable "user_passwords" {
  description = "Write-only passwords keyed by users labels."
  type        = map(string)
  default     = {}
  nullable    = false
  sensitive   = true
  ephemeral   = true

  validation {
    condition = alltrue([
      for key, user in var.users :
      !(user.smb || user.ssh_password_enabled) || try(length(var.user_passwords[key]) > 0, false)
    ])
    error_message = "Supply a password when SMB or SSH password authentication is enabled."
  }
}
