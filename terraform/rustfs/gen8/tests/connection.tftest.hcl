mock_provider "rustfs" {
  mock_data "rustfs_server_info" {
    defaults = {
      mode          = "online"
      offline_disks = 0
      region        = "eu-west-1"
    }
  }

  mock_data "rustfs_buckets" {
    defaults = {
      buckets = [
        { name = "test-data", creation_date = "2026-01-01T00:00:00Z" },
      ]
    }
  }

  mock_data "rustfs_quota_stats" {
    defaults = {
      quota_limit     = 1610612736
      current_usage   = 0
      remaining_quota = 1610612736
    }
  }
}

variables {
  state_passphrase  = "mock-only-passphrase"
  rustfs_endpoint   = "https://nas.example.invalid:30292"
  rustfs_access_key = "mockadmin"
  rustfs_secret_key = "mocksecret"
  buckets = {
    test-data = { quota_gib = 1.5, additional_object_actions = ["s3:DeleteObject"] }
  }
  bucket_credentials = {
    test-data = { access_key = "mock-data", secret_key = "mock-data-secret" }
  }
}

run "rejects_a_plain_http_endpoint" {
  command = plan

  variables {
    rustfs_endpoint = "http://nas.example.invalid:30292"
  }

  expect_failures = [var.rustfs_endpoint]
}

run "rejects_an_endpoint_with_a_path" {
  command = plan

  variables {
    rustfs_endpoint = "https://nas.example.invalid:30292/api"
  }

  expect_failures = [var.rustfs_endpoint]
}

run "rejects_an_endpoint_with_credentials" {
  command = plan

  variables {
    rustfs_endpoint = "https://user:pass@nas.example.invalid:30292"
  }

  expect_failures = [var.rustfs_endpoint]
}

run "accepts_a_scheme_less_tls_endpoint" {
  command = plan

  variables {
    rustfs_endpoint = "nas.example.invalid:30292"
  }
}

run "rejects_a_conflicting_https_scheme" {
  command = plan

  variables {
    rustfs_endpoint = "https://nas.example.invalid:30292"
    rustfs_ssl      = false
  }

  expect_failures = [var.rustfs_endpoint]
}

run "accepts_explicit_http" {
  command = plan

  variables {
    rustfs_endpoint = "http://nas.example.invalid:30292"
    rustfs_ssl      = false
  }
}

run "applies_the_catalog_from_gen8_inputs" {
  command = apply

  assert {
    condition     = module.buckets.bucket_names == toset(["test-data"])
    error_message = "Gen8 must pass the configured buckets to the catalog module."
  }

  assert {
    condition = (
      output.bucket_quotas["test-data"].limit == 1610612736 &&
      output.bucket_quotas["test-data"].usage == 0 &&
      output.bucket_quotas["test-data"].remaining == 1610612736
    )
    error_message = "The quota statistics of an existing bucket must reach the output."
  }

  assert {
    condition     = output.bucket_quotas_summary == ["test-data: 0.0 GB used / 1.6 GB quota, 1.6 GB quota remaining (0%)"]
    error_message = "The summary must show one readable line per bucket, sorted by name."
  }

  assert {
    condition     = output.unmanaged_buckets == "none"
    error_message = "An empty set of unmanaged buckets must read as none."
  }
}

run "rejects_an_offline_cluster" {
  command = plan

  override_data {
    target = data.rustfs_server_info.cluster
    values = { mode = "offline", offline_disks = 0, region = "eu-west-1" }
  }

  expect_failures = [terraform_data.assertions]
}

run "rejects_an_offline_disk" {
  command = plan

  override_data {
    target = data.rustfs_server_info.cluster
    values = { mode = "online", offline_disks = 1, region = "eu-west-1" }
  }

  expect_failures = [terraform_data.assertions]
}

run "rejects_a_region_that_differs_from_the_server" {
  command = plan

  variables {
    buckets = {
      test-data = {
        quota_gib                   = 1.5
        create_bucket_configuration = { location_constraint = "us-west-2" }
      }
    }
  }

  expect_failures = [terraform_data.assertions]
}

run "rejects_a_constraint_when_the_server_region_is_unset" {
  command = plan

  override_data {
    target = data.rustfs_server_info.cluster
    values = { mode = "online", offline_disks = 0, region = null }
  }

  variables {
    buckets = {
      test-data = {
        quota_gib                   = 1.5
        create_bucket_configuration = { location_constraint = "eu-west-1" }
      }
    }
  }

  expect_failures = [terraform_data.assertions]
}

run "accepts_the_eu_alias_for_eu_west_1" {
  command = plan

  variables {
    buckets = {
      test-data = {
        quota_gib                   = 1.5
        create_bucket_configuration = { location_constraint = "EU" }
      }
    }
  }
}

run "accepts_the_server_region" {
  command = plan

  variables {
    buckets = {
      test-data = {
        quota_gib                   = 1.5
        create_bucket_configuration = { location_constraint = "eu-west-1" }
      }
    }
  }
}
