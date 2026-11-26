output "name" {
  description = "Full dataset name."
  value       = truenas_dataset.this.name
}

output "mountpoint" {
  description = "Mountpoint reported by TrueNAS."
  value       = truenas_dataset.this.mountpoint
}

output "nfs" {
  description = "NFS share settings, or null if no share is managed."
  value = var.dataset.nfs == null ? null : {
    enabled = truenas_nfs_share.this[0].enabled
    hosts   = truenas_nfs_share.this[0].hosts
    id      = truenas_nfs_share.this[0].id
    ro      = truenas_nfs_share.this[0].ro
  }
}

output "smb" {
  description = "SMB share settings, or null if no share is managed."
  value = var.dataset.smb == null ? null : {
    enabled = truenas_smb_share.this[0].enabled
    name    = truenas_smb_share.this[0].name
  }
}
