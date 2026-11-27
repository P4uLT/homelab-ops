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
