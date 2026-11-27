mock_provider "rustfs" {}

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

run "plans_the_catalog_from_gen8_inputs" {
  command = plan

  assert {
    condition     = module.buckets.bucket_names == toset(["test-data"])
    error_message = "Gen8 must pass the configured buckets to the catalog module."
  }
}
