data "truenas_group" "entry" {
  for_each = toset([for ace in try(var.dataset.filesystem_acl.entries, []) : ace.group if ace.group != null])

  name = each.value
}

data "truenas_user" "entry" {
  for_each = toset([for ace in try(var.dataset.filesystem_acl.entries, []) : ace.user if ace.user != null])

  username = each.value
}

data "truenas_group" "reader" {
  for_each = toset([for name, right in local.preset_groups : name if right == "READ"])

  name = each.key
}

data "truenas_group" "modifier" {
  for_each = toset([for name, right in local.preset_groups : name if right == "MODIFY"])

  name = each.key
}

data "truenas_user" "preset" {
  for_each = local.preset_users

  username = each.key
}

locals {
  acl = var.dataset.filesystem_acl

  # The dataset reports posix or nfsv4. An ACL entry uses POSIX1E or NFS4.
  acl_type_from_dataset = {
    posix = "POSIX1E"
    nfsv4 = "NFS4"
  }

  preset_enabled = try(local.acl.preset, null) == "nfs4_access"
  preset_groups  = local.preset_enabled ? local.acl.groups : {}
  preset_users   = local.preset_enabled ? local.acl.users : {}

  # Pad GIDs for numeric ordering. Keep aliases so the precondition can reject them.
  grants_by_gid = {
    for grant in concat(
      [for group in data.truenas_group.reader : { gid = group.gid, right = "READ" }],
      [for group in data.truenas_group.modifier : { gid = group.gid, right = "MODIFY" }],
    ) : format("%020d", grant.gid) => grant...
  }

  grants_by_uid = {
    for name, user in data.truenas_user.preset : format("%020d", user.uid) => {
      uid   = user.uid
      right = local.preset_users[name]
    }...
  }

  # TrueNAS basic READ includes directory traversal.
  preset_entries = local.preset_enabled ? concat(
    [{ tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = { BASIC = "INHERIT" } }],
    flatten([
      for grants in values(local.grants_by_gid) : [
        for grant in grants : {
          tag   = "GROUP"
          id    = grant.gid
          type  = "ALLOW"
          perms = { BASIC = grant.right }
          flags = { BASIC = "INHERIT" }
        }
      ]
    ]),
    flatten([
      for grants in values(local.grants_by_uid) : [
        for grant in grants : {
          tag   = "USER"
          id    = grant.uid
          type  = "ALLOW"
          perms = { BASIC = grant.right }
          flags = { BASIC = "INHERIT" }
        }
      ]
    ]),
  ) : null

  filesystem_acl = local.acl == null ? null : merge(local.acl, {
    type = local.preset_enabled ? "NFS4" : local.acl.type
  })

  acl_managed = local.filesystem_acl != null

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
  count = local.acl_managed ? 1 : 0

  path = truenas_dataset.this.mountpoint
}

resource "truenas_filesystem_acl" "this" {
  count = local.acl_managed ? 1 : 0

  path      = data.truenas_filesystem_acl.this[0].path
  recursive = local.filesystem_acl.recursive
  traverse  = local.filesystem_acl.traverse
  entries   = coalesce(local.preset_entries_json, jsonencode(local.ace_payload))

  lifecycle {
    # Replacing a dataset destroys its ACL too.
    prevent_destroy = var.dataset.protect

    precondition {
      # A converted dataset reports its old ACL type until setacl runs.
      condition = (
        data.truenas_filesystem_acl.this[0].acltype == local.filesystem_acl.type ||
        try(local.acl_type_from_dataset[lower(coalesce(truenas_dataset.this.acltype, ""))] == local.filesystem_acl.type, false)
      )
      error_message = "The dataset's ACL type must match the declared filesystem ACL, or be set to it in the same apply."
    }

    precondition {
      condition = alltrue([
        for grants in values(local.grants_by_gid) : length(grants) == 1 && grants[0].gid > 0
      ])
      error_message = "Each ACL preset group must resolve to a distinct positive GID."
    }

    precondition {
      condition = alltrue([
        for grants in values(local.grants_by_uid) : length(grants) == 1 && grants[0].uid > 0
      ])
      error_message = "Each ACL preset user must resolve to a distinct positive UID."
    }
  }
}
