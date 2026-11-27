# Plan-time checks of the deployment the catalog writes to. The data sources
# read the admin API; terraform_data turns a failed assumption into a hard
# plan error, while check blocks only warn.

data "rustfs_server_info" "cluster" {}

data "rustfs_buckets" "existing" {}

locals {
  # A location constraint only passes when the server reports the same region.
  region_constrained_buckets = {
    for name, bucket in var.buckets : name => bucket.create_bucket_configuration.location_constraint
    if try(bucket.create_bucket_configuration.location_constraint != null, false)
  }

  server_region = coalesce(data.rustfs_server_info.cluster.region, "unset")

  # RustFS keeps the historical EU constraint as an alias for eu-west-1.
  accepted_region_constraints = [
    local.server_region,
    local.server_region == "eu-west-1" ? "EU" : local.server_region,
  ]

  mismatched_region_buckets = sort([
    for name, region in local.region_constrained_buckets : name
    if !contains(local.accepted_region_constraints, region)
  ])
}

resource "terraform_data" "assertions" {
  lifecycle {
    precondition {
      condition     = data.rustfs_server_info.cluster.mode == "online"
      error_message = "The RustFS cluster reports ${coalesce(data.rustfs_server_info.cluster.mode, "no mode")}. Bring it online before a plan."
    }

    precondition {
      condition     = data.rustfs_server_info.cluster.offline_disks == 0
      error_message = "The RustFS cluster reports ${coalesce(data.rustfs_server_info.cluster.offline_disks, "an unknown number of")} offline disks. Restore them before a plan."
    }

    precondition {
      condition     = length(local.mismatched_region_buckets) == 0
      error_message = "These buckets pin a location_constraint that differs from the server region (${local.server_region}): ${join(", ", local.mismatched_region_buckets)}. Drop the constraint: RustFS then uses its own region."
    }
  }
}

# The catalog is the source of truth for buckets. An unmanaged bucket usually
# means a manual write or a leftover from another tool.
check "unmanaged_buckets" {
  assert {
    condition     = length(local.unmanaged_bucket_names) == 0
    error_message = "RustFS holds buckets that the catalog doesn't manage: ${join(", ", sort(local.unmanaged_bucket_names))}."
  }
}
