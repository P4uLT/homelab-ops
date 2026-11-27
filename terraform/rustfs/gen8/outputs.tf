output "bucket_quotas" {
  description = "Quota limit, usage, and headroom in bytes for managed and stray buckets. Null means unknown."
  value = {
    for name, stats in local.bucket_statistics : name => {
      limit     = stats.quota_limit
      usage     = stats.current_usage
      remaining = stats.remaining_quota
      percent   = stats.usage_percentage
    }
  }
}

output "bucket_quotas_summary" {
  description = "Bucket usage, quota, and quota remaining in decimal GB. Changed buckets are read after apply."
  value       = local.quota_summary
}

output "storage_capacity_bytes" {
  description = "Filesystem capacities reported by each RustFS drive, in bytes. Don't sum paths that share storage."
  value       = local.storage_capacity_bytes
}

output "storage_capacity_summary" {
  description = "Filesystem usage and availability per RustFS drive in decimal GB, separate from bucket quotas."
  value       = local.storage_capacity_summary
}

output "unmanaged_buckets" {
  description = "Buckets that exist in RustFS without a catalog entry, or none."
  value       = length(local.unmanaged_bucket_names) == 0 ? "none" : join(", ", sort(local.unmanaged_bucket_names))
}
