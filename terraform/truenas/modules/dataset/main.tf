resource "truenas_dataset" "this" {
  name                     = var.dataset.name
  aclmode                  = var.dataset.aclmode
  acltype                  = var.dataset.acltype
  atime                    = var.dataset.atime
  checksum                 = var.dataset.checksum
  comments                 = var.dataset.comments
  compression              = var.dataset.compression
  copies                   = var.dataset.copies
  dedup                    = var.dataset.dedup
  encryption               = var.dataset.encryption
  encryption_algorithm     = var.dataset.encryption_algorithm
  encryption_generate_key  = var.dataset.encryption_generate_key
  exec                     = var.dataset.exec
  inherit_encryption       = var.dataset.inherit_encryption
  quota                    = var.dataset.quota
  readonly                 = var.dataset.readonly
  recordsize               = var.dataset.recordsize
  refquota                 = var.dataset.refquota
  refreservation           = var.dataset.refreservation
  reservation              = var.dataset.reservation
  share_type               = var.dataset.share_type
  snapdir                  = var.dataset.snapdir
  special_small_block_size = var.dataset.special_small_block_size
  sync                     = var.dataset.sync
  type                     = "FILESYSTEM"
  encryption_key           = var.encryption_secrets.key
  encryption_passphrase    = var.encryption_secrets.passphrase
  force_destroy            = false

  lifecycle {
    prevent_destroy = var.dataset.protect
  }
}

# A share created while its service is stopped fails later, at the client.
data "truenas_service" "files" {
  for_each = toset(concat(
    var.dataset.nfs == null ? [] : ["nfs"],
    var.dataset.smb == null ? [] : ["cifs"],
  ))

  name = each.value
}

locals {
  nfs_share = var.dataset.nfs == null ? {} : { share = var.dataset.nfs }

  smb_share = var.dataset.smb == null ? {} : { share = var.dataset.smb }

  # An omitted guestok is false for a legacy share. Other presets keep it unset,
  # so the provider doesn't send a legacy-only option.
  smb_guestok = var.dataset.smb != null && var.dataset.smb.options == null && coalesce(var.dataset.smb.purpose, "LEGACY_SHARE") == "LEGACY_SHARE" ? coalesce(var.dataset.smb.guestok, false) : try(var.dataset.smb.guestok, null)
}

data "truenas_user" "nfs_mapping" {
  for_each = toset(compact([try(var.dataset.nfs.maproot_user, null), try(var.dataset.nfs.mapall_user, null)]))

  username = each.key
}

data "truenas_group" "nfs_mapping" {
  for_each = toset(compact([try(var.dataset.nfs.maproot_group, null), try(var.dataset.nfs.mapall_group, null)]))

  name = each.key
}

resource "truenas_nfs_share" "this" {
  for_each = local.nfs_share

  path             = truenas_dataset.this.mountpoint
  comment          = each.value.comment
  enabled          = each.value.enabled
  expose_snapshots = each.value.expose_snapshots
  hosts            = each.value.hosts
  mapall_group     = each.value.mapall_group == null || each.value.mapall_group == "" ? null : data.truenas_group.nfs_mapping[each.value.mapall_group].name
  mapall_user      = each.value.mapall_user == null || each.value.mapall_user == "" ? null : data.truenas_user.nfs_mapping[each.value.mapall_user].username
  maproot_group    = each.value.maproot_group == null || each.value.maproot_group == "" ? null : data.truenas_group.nfs_mapping[each.value.maproot_group].name
  maproot_user     = each.value.maproot_user == null || each.value.maproot_user == "" ? null : data.truenas_user.nfs_mapping[each.value.maproot_user].username
  networks         = each.value.networks
  ro               = each.value.ro
  security         = each.value.security

  depends_on = [truenas_filesystem_acl.this]

  lifecycle {
    precondition {
      condition     = !each.value.enabled || data.truenas_service.files["nfs"].running
      error_message = "Start the NFS service on TrueNAS before managing an enabled export."
    }
  }
}

resource "truenas_smb_share" "this" {
  for_each = local.smb_share

  path              = truenas_dataset.this.mountpoint
  name              = each.value.name
  abe               = each.value.abe
  acl               = each.value.acl
  audit             = each.value.audit
  browsable         = each.value.browsable
  comment           = each.value.comment
  durablehandle     = each.value.durablehandle
  enabled           = each.value.enabled
  guestok           = local.smb_guestok
  home              = each.value.home
  hostsallow        = each.value.hostsallow
  hostsdeny         = each.value.hostsdeny
  options           = each.value.options
  purpose           = each.value.purpose
  recyclebin        = each.value.recyclebin
  ro                = each.value.ro
  streams           = each.value.streams
  timemachine       = each.value.timemachine
  timemachine_quota = each.value.timemachine_quota

  depends_on = [truenas_filesystem_acl.this]

  lifecycle {
    precondition {
      condition     = !each.value.enabled || data.truenas_service.files["cifs"].running
      error_message = "Start the SMB service on TrueNAS before managing an enabled share."
    }
  }
}
