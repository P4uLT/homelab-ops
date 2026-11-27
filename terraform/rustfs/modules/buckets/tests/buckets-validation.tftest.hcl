mock_provider "rustfs" {}

variables {
  admin_access_key = "mockadmin"
  buckets = {
    test-archive = { quota_gib = 50, versioning = true }
    test-data    = { quota_gib = 20 }
    test-logs    = { quota_gib = 10 }
  }
  bucket_credentials = {
    test-archive = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
    test-data    = { access_key = "mock-walg", secret_key = "mock-walg-secret" }
    test-logs    = { access_key = "mock-test-logs", secret_key = "mock-test-logs-secret" }
  }
}

run "rejects_a_bucket_without_credentials" {
  command = plan

  variables {
    bucket_credentials = {
      test-archive = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      test-data    = { access_key = "mock-walg", secret_key = "mock-walg-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_credentials_without_a_bucket" {
  command = plan

  variables {
    bucket_credentials = {
      test-archive = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      test-data    = { access_key = "mock-walg", secret_key = "mock-walg-secret" }
      test-logs    = { access_key = "mock-test-logs", secret_key = "mock-test-logs-secret" }
      extra        = { access_key = "mock-extra", secret_key = "mock-extra-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_empty_user_credentials" {
  command = plan

  variables {
    bucket_credentials = {
      test-archive = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      test-data    = { access_key = "", secret_key = "" }
      test-logs    = { access_key = "mock-test-logs", secret_key = "mock-test-logs-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_a_short_secret" {
  command = plan

  variables {
    bucket_credentials = {
      test-archive = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      test-data    = { access_key = "mock-walg", secret_key = "short" }
      test-logs    = { access_key = "mock-test-logs", secret_key = "mock-test-logs-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_duplicate_access_keys" {
  command = plan

  variables {
    bucket_credentials = {
      test-archive = { access_key = "mock-shared", secret_key = "mock-backups-secret" }
      test-data    = { access_key = "mock-shared", secret_key = "mock-walg-secret" }
      test-logs    = { access_key = "mock-test-logs", secret_key = "mock-test-logs-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_the_admin_access_key" {
  command = plan

  variables {
    bucket_credentials = {
      test-archive = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      test-data    = { access_key = "mockadmin", secret_key = "mock-walg-secret" }
      test-logs    = { access_key = "mock-test-logs", secret_key = "mock-test-logs-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_a_zero_quota" {
  command = plan

  variables {
    buckets = {
      test-archive = { quota_gib = 50, versioning = true }
      test-data    = { quota_gib = 0 }
      test-logs    = { quota_gib = 10 }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_a_sub_byte_quota" {
  command = plan

  variables {
    buckets = {
      test-archive = { quota_gib = 50, versioning = true }
      test-data    = { quota_gib = 0.0000000001 }
      test-logs    = { quota_gib = 10 }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_a_quota_larger_than_provider_int64" {
  command = plan

  variables {
    buckets = {
      test-archive = { quota_gib = 8589934592 }
      test-data    = { quota_gib = 20 }
      test-logs    = { quota_gib = 10 }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_wildcard_actions" {
  command = plan

  variables {
    buckets = {
      test-archive = { quota_gib = 50 }
      test-data    = { quota_gib = 20, additional_object_actions = ["s3:*"] }
      test-logs    = { quota_gib = 10 }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_actions_in_the_wrong_scope" {
  command = plan

  variables {
    buckets = {
      test-archive = { quota_gib = 50, additional_bucket_actions = ["s3:GetObject"] }
      test-data    = { quota_gib = 20 }
      test-logs    = { quota_gib = 10 }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_a_bucket_name_with_a_wildcard" {
  command = plan

  variables {
    buckets = {
      "test-*"  = { quota_gib = 50 }
      test-data = { quota_gib = 20 }
      test-logs = { quota_gib = 10 }
    }
  }

  expect_failures = [var.buckets]
}
