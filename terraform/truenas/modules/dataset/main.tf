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
  count = var.dataset.nfs == null ? 0 : 1

  path             = truenas_dataset.this.mountpoint
  comment          = var.dataset.nfs.comment
  enabled          = var.dataset.nfs.enabled
  expose_snapshots = var.dataset.nfs.expose_snapshots
  hosts            = var.dataset.nfs.hosts
  mapall_group     = var.dataset.nfs.mapall_group == null || var.dataset.nfs.mapall_group == "" ? null : data.truenas_group.nfs_mapping[var.dataset.nfs.mapall_group].name
  mapall_user      = var.dataset.nfs.mapall_user == null || var.dataset.nfs.mapall_user == "" ? null : data.truenas_user.nfs_mapping[var.dataset.nfs.mapall_user].username
  maproot_group    = var.dataset.nfs.maproot_group == null || var.dataset.nfs.maproot_group == "" ? null : data.truenas_group.nfs_mapping[var.dataset.nfs.maproot_group].name
  maproot_user     = var.dataset.nfs.maproot_user == null || var.dataset.nfs.maproot_user == "" ? null : data.truenas_user.nfs_mapping[var.dataset.nfs.maproot_user].username
  networks         = var.dataset.nfs.networks
  ro               = var.dataset.nfs.ro
  security         = var.dataset.nfs.security

  depends_on = [truenas_filesystem_acl.this]

  lifecycle {
    precondition {
      condition     = !var.dataset.nfs.enabled || data.truenas_service.files["nfs"].running
      error_message = "Start the NFS service on TrueNAS before managing an enabled export."
    }
  }
}

resource "truenas_smb_share" "this" {
  count = var.dataset.smb == null ? 0 : 1

  path              = truenas_dataset.this.mountpoint
  name              = var.dataset.smb.name
  abe               = var.dataset.smb.abe
  acl               = var.dataset.smb.acl
  audit             = var.dataset.smb.audit
  browsable         = var.dataset.smb.browsable
  comment           = var.dataset.smb.comment
  durablehandle     = var.dataset.smb.durablehandle
  enabled           = var.dataset.smb.enabled
  guestok           = local.smb_guestok
  home              = var.dataset.smb.home
  hostsallow        = var.dataset.smb.hostsallow
  hostsdeny         = var.dataset.smb.hostsdeny
  options           = var.dataset.smb.options
  purpose           = var.dataset.smb.purpose
  recyclebin        = var.dataset.smb.recyclebin
  ro                = var.dataset.smb.ro
  streams           = var.dataset.smb.streams
  timemachine       = var.dataset.smb.timemachine
  timemachine_quota = var.dataset.smb.timemachine_quota

  depends_on = [truenas_filesystem_acl.this]

  lifecycle {
    precondition {
      condition     = !var.dataset.smb.enabled || data.truenas_service.files["cifs"].running
      error_message = "Start the SMB service on TrueNAS before managing an enabled share."
    }
  }
}
