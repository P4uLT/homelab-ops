locals {
  bytes_per_gb = 1000000000

  existing_bucket_names  = toset([for bucket in data.rustfs_buckets.existing.buckets : bucket.name])
  unmanaged_bucket_names = setsubtract(local.existing_bucket_names, toset(keys(var.buckets)))

  bucket_statistics = merge(data.rustfs_quota_stats.this, data.rustfs_quota_stats.unmanaged)

  quota_summary = [
    for name in sort(keys(local.bucket_statistics)) : format(
      "%s: %s used / %s, %s quota remaining (%s%%)",
      name,
      try(format("%.1f GB", local.bucket_statistics[name].current_usage / local.bytes_per_gb), "unknown"),
      try(format("%.1f GB quota", local.bucket_statistics[name].quota_limit / local.bytes_per_gb), "no quota"),
      try(format("%.1f GB", local.bucket_statistics[name].remaining_quota / local.bytes_per_gb), "unknown"),
      try(format("%.0f", local.bucket_statistics[name].usage_percentage), "?"),
    )
  ]

  # Keep drives separate: two paths can share a filesystem or storage pool.
  storage_capacity_bytes = flatten([
    for server in coalesce(data.rustfs_server_info.cluster.servers, []) : [
      for drive in coalesce(server.drives, []) : {
        server    = server.endpoint
        path      = drive.path
        total     = drive.totalspace
        used      = drive.usedspace
        available = drive.availspace
      }
    ]
  ])

  storage_capacity_summary = sort([
    for drive in local.storage_capacity_bytes : format(
      "%s %s: %s used, %s available, %s total",
      drive.server,
      drive.path,
      try(format("%.1f GB", drive.used / local.bytes_per_gb), "unknown"),
      try(format("%.1f GB", drive.available / local.bytes_per_gb), "unknown"),
      try(format("%.1f GB", drive.total / local.bytes_per_gb), "unknown"),
    )
  ])
}
