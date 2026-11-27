# The quota subsystem reports a bucket's limit, usage, and headroom. Read only
# buckets that already exist: a data source for a new bucket fails the plan.
data "rustfs_quota_stats" "this" {
  for_each = local.existing_bucket_names

  bucket = each.value
}

locals {
  bytes_per_gib = pow(2, 30)

  # One readable line per bucket for a plan review. The numeric output below
  # keeps the exact byte values for scripts.
  quota_summary = [
    for name in sort(keys(data.rustfs_quota_stats.this)) : format(
      "%s: %s%% used, %s limit, %s free",
      name,
      try(format("%.0f", data.rustfs_quota_stats.this[name].usage_percentage), "?"),
      try(format("%.1f GiB", data.rustfs_quota_stats.this[name].quota_limit / local.bytes_per_gib), "no quota"),
      try(format("%.1f GiB", data.rustfs_quota_stats.this[name].remaining_quota / local.bytes_per_gib), "unknown"),
    )
  ]
}

output "bucket_quotas" {
  description = "Quota limit, usage, and headroom in bytes for each existing bucket."
  value = {
    for name, stats in data.rustfs_quota_stats.this : name => {
      limit     = stats.quota_limit
      usage     = stats.current_usage
      remaining = stats.remaining_quota
      percent   = stats.usage_percentage
    }
  }
}

output "bucket_quotas_summary" {
  description = "One readable line per existing bucket: usage, limit, and headroom."
  value       = local.quota_summary
}

output "unmanaged_buckets" {
  description = "Buckets that exist in RustFS without a catalog entry, or none."
  value       = length(local.unmanaged_bucket_names) == 0 ? "none" : join(", ", sort(local.unmanaged_bucket_names))
}
