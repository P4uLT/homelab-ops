mock_provider "rustfs" {
  mock_data "rustfs_server_info" {
    defaults = {
      mode          = "online"
      offline_disks = 0
      region        = "eu-west-1"
      servers = [{
        endpoint        = "nas.example.invalid"
        max_procs       = 8
        mem_alloc       = 0
        mem_total_alloc = 0
        num_cpu         = 8
        state           = "online"
        uptime          = 3600
        version         = "fixture"
        drives = [{
          endpoint      = "nas.example.invalid/data"
          healing       = false
          local         = true
          path          = "/data"
          runtime_state = "ok"
          state         = "ok"
          uuid          = "fixture-drive"
          utilization   = 25
          totalspace    = 2000000000000
          usedspace     = 500000000000
          availspace    = 1500000000000
        }]
      }]
    }
  }
  mock_data "rustfs_buckets" { defaults = { buckets = [] } }
  mock_data "rustfs_quota_stats" {
    defaults = {
      quota_limit      = 2000000000
      current_usage    = 500000000
      remaining_quota  = 1500000000
      usage_percentage = 25
    }
  }
}
variables {
  state_passphrase   = "mock-only-passphrase"
  rustfs_endpoint    = "https://nas.example.invalid:30292"
  rustfs_access_key  = "mockadmin"
  rustfs_secret_key  = "mocksecret"
  buckets            = { test-data = { quota_gib = 1.5 } }
  bucket_credentials = { test-data = { access_key = "mock-data", secret_key = "mock-data-secret" } }
}
run "includes_new_buckets_after_apply" {
  command = apply
  assert {
    condition     = output.bucket_quotas_summary == ["test-data: 0.5 GB used / 2.0 GB quota, 1.5 GB quota remaining (25%)"]
    error_message = "A newly created bucket must have a post-apply GB summary."
  }
  assert {
    condition     = output.bucket_quotas["test-data"].usage == 500000000 && output.bucket_quotas["test-data"].remaining == 1500000000
    error_message = "Script outputs must preserve exact bytes."
  }
}
run "distinguishes_filesystem_availability_from_quotas" {
  command = plan
  assert {
    condition     = one(output.storage_capacity_summary) == "nas.example.invalid /data: 500.0 GB used, 1500.0 GB available, 2000.0 GB total"
    error_message = "Filesystem availability must be separate from bucket quota headroom."
  }
}
run "keeps_unknown_usage_explicit" {
  command = apply
  override_data {
    target = data.rustfs_quota_stats.this
    values = {
      quota_limit      = null
      current_usage    = null
      remaining_quota  = null
      usage_percentage = null
    }
  }
  assert {
    condition     = output.bucket_quotas_summary == ["test-data: unknown used / no quota, unknown quota remaining (?%)"]
    error_message = "Missing measurements must not masquerade as zero use or free space."
  }
}
run "reports_unmanaged_buckets_without_dropping_managed_ones" {
  command = apply
  override_data {
    target = data.rustfs_buckets.existing
    values = { buckets = [{ name = "stray-data", creation_date = "2026-01-01T00:00:00Z" }] }
  }
  expect_failures = [check.unmanaged_buckets]
  assert {
    condition     = toset(keys(output.bucket_quotas)) == toset(["test-data", "stray-data"]) && output.unmanaged_buckets == "stray-data"
    error_message = "The summary must retain both configured and stray bucket names."
  }
}
