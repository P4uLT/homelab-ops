variable "state_passphrase" {
  description = "Passphrase from TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
  ephemeral   = true

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
    name = string
    filesystem_acl = optional(object({
      preset         = optional(string)
      group_gid      = optional(number)
      group_name     = optional(string)
      group_names    = optional(set(string), [])
      type           = optional(string)
      inherit_access = optional(bool, false)
      entries = optional(list(object({
        tag         = string
        who         = optional(string)
        id          = optional(number)
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
