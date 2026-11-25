data "truenas_group" "entry" {
  for_each = toset([for ace in try(var.dataset.filesystem_acl.entries, []) : ace.group if ace.group != null])

  name = each.value
}

data "truenas_user" "entry" {
  for_each = toset([for ace in try(var.dataset.filesystem_acl.entries, []) : ace.user if ace.user != null])

  username = each.value
}

data "truenas_group" "acl" {
  for_each = local.acl == null ? {} : (
    local.acl.group_name != null ? { managed = local.acl.group_name } : {
      for name in local.acl.group_names : name => name
    }
  )

  name = each.value
}

locals {
  acl = var.dataset.filesystem_acl

  # The dataset reports posix or nfsv4. An ACL entry uses POSIX1E or NFS4.
  acl_type_from_dataset = {
    posix = "POSIX1E"
    nfsv4 = "NFS4"
  }

  # Sort by GID so the entry order stays stable.
  acl_group_gids = try(local.acl.group_gid, null) != null ? [local.acl.group_gid] : [
    for gid in sort(distinct([for group in data.truenas_group.acl : format("%020d", group.gid)])) : tonumber(gid)
  ]

  # SMB needs an NFSv4 ACL, so the preset emits one inherited entry per right.
  preset_entries = local.acl == null || local.acl.preset == null ? null : [
    for ace in concat(
      [{ group_id = tonumber(null) }],
      [for gid in local.acl_group_gids : { group_id = gid }],
      ) : merge(
      {
        tag   = ace.group_id == null ? "owner@" : "GROUP"
        type  = "ALLOW"
        perms = { BASIC = ace.group_id == null ? "FULL_CONTROL" : "MODIFY" }
        flags = { BASIC = "INHERIT" }
      },
      ace.group_id == null ? {} : { id = ace.group_id }
    )
  ]

  filesystem_acl = local.acl == null ? null : merge(local.acl, {
    type           = local.acl.preset == "nfs4_group_rw" ? "NFS4" : local.acl.type
    inherit_access = local.acl.inherit_access
  })

  acl_managed = local.filesystem_acl == null ? {} : { managed = local.filesystem_acl }

  acl_entries = try(local.acl.entries, [])
  acl_inherit = try(local.acl.inherit_access, false)

  # POSIX inheritance duplicates each access entry as a default entry.
  ace_source = local.acl_inherit ? concat(
    [for ace in local.acl_entries : merge(ace, { default = false })],
    [for ace in local.acl_entries : merge(ace, { default = true })],
  ) : local.acl_entries

  # Provider shape: drop module-only fields, resolve named identities, and
  # spell basic permissions as BASIC.
  ace_payload = [
    for ace in local.ace_source : {
      for key, value in merge(
        { for key, value in ace : key => value if !contains(["basic_perms", "basic_flags", "group", "user"], key) },
        ace.group == null ? {} : { id = data.truenas_group.entry[ace.group].gid },
        ace.user == null ? {} : { id = data.truenas_user.entry[ace.user].uid },
        ace.basic_perms == null ? {} : { perms = { BASIC = ace.basic_perms } },
        ace.basic_flags == null ? {} : { flags = { BASIC = ace.basic_flags } }
      ) : key => value if value != null
    }
  ]

  preset_entries_json = local.preset_entries == null ? null : jsonencode(local.preset_entries)

}

data "truenas_filesystem_acl" "this" {
  for_each = local.acl_managed

  path = truenas_dataset.this.mountpoint
}

resource "truenas_filesystem_acl" "this" {
  for_each = local.acl_managed

  path      = data.truenas_filesystem_acl.this[each.key].path
  recursive = each.value.recursive
  traverse  = each.value.traverse
  entries   = coalesce(local.preset_entries_json, jsonencode(local.ace_payload))

  lifecycle {
    # Replacing a dataset destroys its ACL too.
    prevent_destroy = var.dataset.protect

    precondition {
      # A converted dataset reports its old ACL type until setacl runs.
      condition = (
        data.truenas_filesystem_acl.this[each.key].acltype == each.value.type ||
        try(local.acl_type_from_dataset[lower(coalesce(truenas_dataset.this.acltype, ""))] == each.value.type, false)
      )
      error_message = "The dataset's ACL type must match the declared filesystem ACL, or be set to it in the same apply."
    }

    precondition {
      condition     = alltrue([for gid in local.acl_group_gids : gid > 0])
      error_message = "The ACL preset refuses a group whose ID is 0."
    }
  }
}
