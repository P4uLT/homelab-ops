variable "dataset" {
  description = "One filesystem dataset and its optional NFS and SMB shares."
  type = object({
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
  })
  nullable = false

  validation {
    condition = var.dataset.filesystem_acl == null ? true : (
      var.dataset.filesystem_acl.preset == null
      ? var.dataset.filesystem_acl.group_gid == null && var.dataset.filesystem_acl.group_name == null && length(var.dataset.filesystem_acl.group_names) == 0
      : try(
        var.dataset.filesystem_acl.preset == "posix_group_rw_others_ro" &&
        length(compact([
          var.dataset.filesystem_acl.group_gid == null ? "" : "group_gid",
          var.dataset.filesystem_acl.group_name == null ? "" : "group_name",
          length(var.dataset.filesystem_acl.group_names) == 0 ? "" : "group_names",
        ])) == 1 &&
        (var.dataset.filesystem_acl.group_gid == null ? true :
          var.dataset.filesystem_acl.group_gid > 0 && floor(var.dataset.filesystem_acl.group_gid) == var.dataset.filesystem_acl.group_gid
        ) &&
        alltrue([
          for name in concat(var.dataset.filesystem_acl.group_name == null ? [] : [var.dataset.filesystem_acl.group_name], tolist(var.dataset.filesystem_acl.group_names)) :
          trimspace(name) != "" && trimspace(name) == name
        ]) &&
        var.dataset.filesystem_acl.type == null &&
        !var.dataset.filesystem_acl.inherit_access &&
        length(var.dataset.filesystem_acl.entries) == 0,
        false
      )
    )
    error_message = "Use a known ACL preset with exactly one of group_gid, group_name, or group_names, and no custom ACL settings."
  }

  validation {
    condition = var.dataset.filesystem_acl == null ? true : var.dataset.filesystem_acl.preset != null ? true : try(
      contains(["POSIX1E", "NFS4"], var.dataset.filesystem_acl.type) &&
      length(var.dataset.filesystem_acl.entries) > 0 &&
      alltrue([
        for ace in var.dataset.filesystem_acl.entries :
        (ace.who == null || ace.id == null) &&
        ((ace.perms == null) != (ace.basic_perms == null)) &&
        (ace.flags == null || ace.basic_flags == null) &&
        (var.dataset.filesystem_acl.type == "POSIX1E"
          ? ace.type == null && ace.flags == null && ace.basic_flags == null && ace.basic_perms == null
        : contains(["ALLOW", "DENY"], ace.type) && ace.default == null)
      ]),
      false
    )
    error_message = "Declare a non-empty POSIX1E or NFS4 ACL. Use one permission form and at most one identity and flag form per entry."
  }

  validation {
    condition = try(!var.dataset.filesystem_acl.inherit_access || (
      var.dataset.filesystem_acl.type == "POSIX1E" &&
      alltrue([for ace in var.dataset.filesystem_acl.entries : ace.default == null || ace.default == false])
    ), var.dataset.filesystem_acl == null)
    error_message = "Use inherit_access only with POSIX access entries. Don't include explicit inherited entries."
  }

  validation {
    condition = var.dataset.nfs == null ? true : try(
      length(var.dataset.nfs.hosts) + length(var.dataset.nfs.networks) > 0 &&
      alltrue([for host in var.dataset.nfs.hosts :
        can(cidrhost("${host}/128", 0)) ||
        can(regex("^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$", host))
      ]) &&
      alltrue([for network in var.dataset.nfs.networks :
        can(cidrhost(network, 0)) && try(tonumber(split("/", network)[1]) > 0, false)
      ]),
      false
    )
    error_message = "An NFS export needs explicit hosts or restricted CIDR networks, without wildcards or /0."
  }

  validation {
    condition = var.dataset.nfs == null ? true : (
      (var.dataset.nfs.maproot_user == null && var.dataset.nfs.maproot_group == null) ||
      (var.dataset.nfs.mapall_user == null && var.dataset.nfs.mapall_group == null)
    )
    error_message = "Use either maproot or mapall for an NFS export, not both."
  }
}

variable "encryption_secrets" {
  description = "Write-only key or passphrase for dataset creation."
  type = object({
    key        = optional(string)
    passphrase = optional(string)
  })
  default   = {}
  nullable  = false
  sensitive = true
  ephemeral = true
}
