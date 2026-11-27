locals {
  existing_bucket_names  = toset([for bucket in data.rustfs_buckets.existing.buckets : bucket.name])
  unmanaged_bucket_names = setsubtract(local.existing_bucket_names, toset(keys(var.buckets)))
}
