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
