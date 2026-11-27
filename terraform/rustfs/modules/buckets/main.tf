resource "rustfs_bucket" "this" {
  for_each                       = var.buckets
  name                           = each.key
  bucket_namespace               = each.value.bucket_namespace
  object_ownership               = each.value.object_ownership
  object_lock_enabled_for_bucket = each.value.object_lock_enabled_for_bucket
  create_bucket_configuration    = each.value.create_bucket_configuration
  force_destroy                  = each.value.force_destroy
}

resource "rustfs_bucket_versioning" "this" {
  for_each = local.bucket_versioning
  bucket   = rustfs_bucket.this[each.key].name
  status   = each.value
}

resource "rustfs_quota" "this" {
  for_each = local.bucket_quotas_bytes
  bucket   = rustfs_bucket.this[each.key].name
  quota    = each.value
}
