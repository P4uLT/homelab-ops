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
  # POSIX named group entries are ordered by numeric GID.
  acl_group_gids = try(local.acl.group_gid, null) != null ? [local.acl.group_gid] : [
    for gid in sort(distinct([for group in data.truenas_group.acl : format("%020d", group.gid)])) : tonumber(gid)
  ]

  posix_group_rw_others_ro = [
    for ace in concat(
      [{ tag = "USER_OBJ", write = true }, { tag = "GROUP_OBJ", write = false }],
      [for gid in local.acl_group_gids : { tag = "GROUP", id = gid, write = true }],
      [{ tag = "MASK", write = true }, { tag = "OTHER", write = false }],
      ) : {
      tag         = ace.tag
      id          = try(ace.id, null)
      who         = null
      type        = null
      default     = null
      perms       = { READ = true, WRITE = ace.write, EXECUTE = true }
      flags       = null
      basic_perms = null
      basic_flags = null
    }
  ]

  filesystem_acl = local.acl == null ? null : (
    local.acl.preset == "posix_group_rw_others_ro" ? merge(local.acl, {
      type           = "POSIX1E"
      inherit_access = true
      entries        = local.posix_group_rw_others_ro
    }) : local.acl
  )
}

data "truenas_filesystem_acl" "this" {
  for_each = var.dataset.filesystem_acl == null ? toset([]) : toset(["managed"])

  path = truenas_dataset.this.mountpoint
}

resource "truenas_filesystem_acl" "this" {
  for_each = var.dataset.filesystem_acl == null ? {} : { managed = local.filesystem_acl }

  path      = data.truenas_filesystem_acl.this[each.key].path
  recursive = false
  entries = jsonencode([
    for ace in(each.value.inherit_access ? concat(
      [for entry in each.value.entries : merge(entry, { default = false })],
      [for entry in each.value.entries : merge(entry, { default = true })],
      ) : each.value.entries) : {
      for key, value in merge(
        { for key, value in ace : key => value if !contains(["basic_perms", "basic_flags"], key) },
        ace.basic_perms == null ? {} : { perms = { BASIC = ace.basic_perms } },
        ace.basic_flags == null ? {} : { flags = { BASIC = ace.basic_flags } }
      ) : key => value if value != null
    }
  ])

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = data.truenas_filesystem_acl.this[each.key].acltype == each.value.type
      error_message = "The dataset's ACL type must match the declared filesystem ACL."
    }
  }
}
