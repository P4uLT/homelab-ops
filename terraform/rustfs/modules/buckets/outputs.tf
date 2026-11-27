output "bucket_names" {
  description = "Names of the buckets managed by the catalog."
  value       = toset(keys(rustfs_bucket.this))
}
