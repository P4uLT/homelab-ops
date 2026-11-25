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

resource "truenas_nfs_share" "this" {
  for_each = var.dataset.nfs == null ? {} : { share = var.dataset.nfs }

  path             = truenas_dataset.this.mountpoint
  comment          = each.value.comment
  enabled          = each.value.enabled
  expose_snapshots = each.value.expose_snapshots
  hosts            = each.value.hosts
  mapall_group     = each.value.mapall_group
  mapall_user      = each.value.mapall_user
  maproot_group    = each.value.maproot_group
  maproot_user     = each.value.maproot_user
  networks         = each.value.networks
  ro               = each.value.ro
  security         = each.value.security

  depends_on = [truenas_filesystem_acl.this]
}

resource "truenas_smb_share" "this" {
  for_each = var.dataset.smb == null ? {} : { share = var.dataset.smb }

  path          = truenas_dataset.this.mountpoint
  name          = each.value.name
  abe           = each.value.abe
  acl           = each.value.acl
  audit         = each.value.audit
  browsable     = each.value.browsable
  comment       = each.value.comment
  durablehandle = each.value.durablehandle
  enabled       = each.value.enabled
  guestok = (
    each.value.options == null && coalesce(each.value.purpose, "LEGACY_SHARE") == "LEGACY_SHARE"
    ? coalesce(each.value.guestok, false)
    : each.value.guestok
  )
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
}
