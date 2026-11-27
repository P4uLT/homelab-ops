# Managed buckets must exist and have their quota before statistics are read.
# A plan defers these reads when the catalog changes, including new buckets.
data "rustfs_quota_stats" "this" {
  for_each = module.buckets.bucket_names

  bucket     = each.value
  depends_on = [module.buckets]
}

# Stray buckets have no resource dependency in this root.
data "rustfs_quota_stats" "unmanaged" {
  for_each = local.unmanaged_bucket_names

  bucket = each.value
}
