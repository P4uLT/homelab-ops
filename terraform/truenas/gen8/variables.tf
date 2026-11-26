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

variable "datasets" {
  description = "Managed filesystem datasets, keyed by stable deployment labels."
  type = map(object({
    name    = string
    protect = optional(bool, true)
    filesystem_acl = optional(object({
      preset         = optional(string)
      groups         = optional(map(string), {})
      users          = optional(map(string), {})
      type           = optional(string)
      inherit_access = optional(bool, false)
      recursive      = optional(bool, false)
      traverse       = optional(bool, false)
      entries = optional(list(object({
        tag         = string
        who         = optional(string)
        id          = optional(number)
        group       = optional(string)
        user        = optional(string)
        type        = optional(string)
        default     = optional(bool)
        perms       = optional(map(bool))
        basic_perms = optional(string)
        flags       = optional(map(bool))
        basic_flags = optional(string)
      })), [])
    }))
    aclmode                  = optional(string)
    acltype                  = optional(string)
    atime                    = optional(string)
    checksum                 = optional(string)
    comments                 = optional(string)
    compression              = optional(string)
    copies                   = optional(number)
    dedup                    = optional(string)
    encryption               = optional(bool)
    encryption_algorithm     = optional(string)
    encryption_generate_key  = optional(bool)
    exec                     = optional(string)
    inherit_encryption       = optional(bool)
    quota                    = optional(number)
    readonly                 = optional(string)
    recordsize               = optional(string)
    refquota                 = optional(number)
    refreservation           = optional(number)
    reservation              = optional(number)
    share_type               = optional(string)
    snapdir                  = optional(string)
    special_small_block_size = optional(number)
    sync                     = optional(string)
    nfs = optional(object({
      comment          = optional(string)
      enabled          = optional(bool, true)
      expose_snapshots = optional(bool)
      hosts            = optional(list(string), [])
      mapall_group     = optional(string)
      mapall_user      = optional(string)
      maproot_group    = optional(string)
      maproot_user     = optional(string)
      networks         = optional(list(string), [])
      ro               = optional(bool, false)
      security         = optional(list(string))
    }))
    smb = optional(object({
      name = string
      abe  = optional(bool)
      acl  = optional(bool)
      audit = optional(object({
        enable      = optional(bool)
        ignore_list = optional(list(string))
        watch_list  = optional(list(string))
      }))
      browsable     = optional(bool)
      comment       = optional(string)
      durablehandle = optional(bool)
      enabled       = optional(bool, true)
      guestok       = optional(bool)
      home          = optional(bool)
      hostsallow    = optional(list(string))
      hostsdeny     = optional(list(string))
      options = optional(object({
        aapl_name_mangling    = optional(bool)
        acl                   = optional(bool)
        afp                   = optional(bool)
        auto_dataset_creation = optional(bool)
        auto_quota            = optional(number)
        auto_snapshot         = optional(bool)
        auxsmbconf            = optional(string)
        dataset_naming_schema = optional(string)
        durablehandle         = optional(bool)
        fsrvp                 = optional(bool)
        grace_period          = optional(number)
        guestok               = optional(bool)
        home                  = optional(bool)
        hostsallow            = optional(list(string))
        hostsdeny             = optional(list(string))
        path_suffix           = optional(string)
        recyclebin            = optional(bool)
        remote_path           = optional(list(string))
        shadowcopy            = optional(bool)
        streams               = optional(bool)
        timemachine           = optional(bool)
        timemachine_quota     = optional(number)
      }))
      purpose           = optional(string)
      recyclebin        = optional(bool)
      ro                = optional(bool)
      streams           = optional(bool)
      timemachine       = optional(bool)
      timemachine_quota = optional(number)
    }))
  }))
  nullable = false

  validation {
    condition = try(
      length(toset([for dataset in var.datasets : dataset.name])) == length(var.datasets) &&
      alltrue([for dataset in var.datasets : startswith(dataset.name, "tank/")]),
      false
    )
    error_message = "Dataset names must be distinct and under tank/."
  }

  validation {
    condition = try(alltrue([
      for dataset in var.datasets : dataset.nfs == null ? true :
      length(dataset.nfs.hosts) + length(dataset.nfs.networks) > 0
    ]), false)
    error_message = "Each NFS export needs at least one host or network."
  }
}

variable "dataset_encryption_secrets" {
  description = "Optional write-only encryption inputs keyed by dataset label."
  type = map(object({
    key        = optional(string)
    passphrase = optional(string)
  }))
  default   = {}
  nullable  = false
  sensitive = true
  ephemeral = true
}

variable "rustfs_app_enabled" {
  description = "Install the RustFS catalog application. Turning it off after install plans removal."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition = !var.rustfs_app_enabled || try(
      contains(keys(var.datasets), "rustfs") &&
      var.datasets["rustfs"].name == var.rustfs_app_dataset &&
      var.datasets["rustfs"].share_type == "APPS" &&
      length(trimspace(var.rustfs_app_dataset)) > 0,
      false
    )
    error_message = "Enable the app only with a \"rustfs\" datasets entry named by rustfs_app_dataset with share_type = \"APPS\"."
  }

  validation {
    condition = !var.rustfs_app_enabled || try(
      var.rustfs_app_version != null &&
      length(var.rustfs_app_version) > 0 &&
      trimspace(var.rustfs_app_version) == var.rustfs_app_version &&
      can(regex("^[0-9]+(\\.[0-9]+)+$", var.rustfs_app_version)),
      false
    )
    error_message = "Set rustfs_app_version to a pinned catalog version such as 1.1.46."
  }

  validation {
    condition = !var.rustfs_app_enabled || try(
      length(var.rustfs_app_access_key) >= 3 &&
      length(var.rustfs_app_access_key) <= 20 &&
      length(var.rustfs_app_secret_key) >= 8 &&
      length(var.rustfs_app_secret_key) <= 40,
      false
    )
    error_message = "Set rustfs_app_access_key (3 to 20 characters) and rustfs_app_secret_key (8 to 40 characters)."
  }

  validation {
    condition = !var.rustfs_app_enabled || try(
      var.rustfs_app_certificate_id > 0 &&
      floor(var.rustfs_app_certificate_id) == var.rustfs_app_certificate_id,
      false
    )
    error_message = "Set rustfs_app_certificate_id to the positive ID of an existing TrueNAS certificate."
  }

  validation {
    condition = !var.rustfs_app_enabled || try(
      (
        can(cidrhost("${var.rustfs_app_api_bind_ip}/32", 0)) ||
        can(regex("^[0-9A-Fa-f:]+$", var.rustfs_app_api_bind_ip))
      ) &&
      !contains(["0.0.0.0", "::", "0:0:0:0:0:0:0:0"], var.rustfs_app_api_bind_ip),
      false
    )
    error_message = "Set rustfs_app_api_bind_ip to one interface address. A wildcard bind isn't allowed."
  }
}

variable "rustfs_app_version" {
  description = "Catalog chart version to install. The chart for RustFS 1.0.6 is 1.1.46."
  type        = string
  default     = null
}

variable "rustfs_app_dataset" {
  description = "Dataset holding the RustFS data, as a dataset name under tank/."
  type        = string
  default     = "tank/rustfs"
  nullable    = false
}

variable "rustfs_app_api_port" {
  description = "Published HTTPS API port of the RustFS application."
  type        = number
  default     = 30292
  nullable    = false

  validation {
    condition = (
      var.rustfs_app_api_port >= 1 &&
      var.rustfs_app_api_port <= 65535 &&
      floor(var.rustfs_app_api_port) == var.rustfs_app_api_port
    )
    error_message = "rustfs_app_api_port must be a whole number from 1 to 65535."
  }

  validation {
    condition     = var.rustfs_app_api_port != var.rustfs_app_web_port
    error_message = "rustfs_app_api_port and rustfs_app_web_port must differ."
  }
}

variable "rustfs_app_web_port" {
  description = "Console port of the RustFS application. The chart leaves it unpublished."
  type        = number
  default     = 30293
  nullable    = false

  validation {
    condition = (
      var.rustfs_app_web_port >= 1 &&
      var.rustfs_app_web_port <= 65535 &&
      floor(var.rustfs_app_web_port) == var.rustfs_app_web_port
    )
    error_message = "rustfs_app_web_port must be a whole number from 1 to 65535."
  }
}

variable "rustfs_app_certificate_id" {
  description = "TrueNAS certificate ID for the RustFS API. Without it the chart serves HTTP."
  type        = number
  default     = null
}

variable "rustfs_app_api_bind_ip" {
  description = "Interface address the RustFS API publishes on."
  type        = string
  default     = null
}

variable "rustfs_app_access_key" {
  description = "RustFS admin access key, minted outside Terraform."
  type        = string
  default     = null
  sensitive   = true
}

variable "rustfs_app_secret_key" {
  description = "RustFS admin secret key, minted outside Terraform."
  type        = string
  default     = null
  sensitive   = true
}
