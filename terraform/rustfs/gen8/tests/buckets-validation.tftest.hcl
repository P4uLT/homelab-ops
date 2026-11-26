mock_provider "rustfs" {}

variables {
  state_passphrase  = "mock-only-passphrase"
  rustfs_endpoint   = "https://nas.example.invalid:30292"
  rustfs_access_key = "mockadmin"
  rustfs_secret_key = "mocksecret"
  buckets = {
    k8s-backups = { quota_bytes = 53687091200, versioning = true }
    wal-g       = { quota_bytes = 21474836480 }
    loki        = { quota_bytes = 10737418240 }
  }
  bucket_credentials = {
    k8s-backups = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
    wal-g       = { access_key = "mock-walg", secret_key = "mock-walg-secret" }
    loki        = { access_key = "mock-loki", secret_key = "mock-loki-secret" }
  }
}

run "rejects_a_bucket_without_credentials" {
  command = plan

  variables {
    bucket_credentials = {
      k8s-backups = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      wal-g       = { access_key = "mock-walg", secret_key = "mock-walg-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_credentials_without_a_bucket" {
  command = plan

  variables {
    bucket_credentials = {
      k8s-backups = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      wal-g       = { access_key = "mock-walg", secret_key = "mock-walg-secret" }
      loki        = { access_key = "mock-loki", secret_key = "mock-loki-secret" }
      extra       = { access_key = "mock-extra", secret_key = "mock-extra-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_empty_user_credentials" {
  command = plan

  variables {
    bucket_credentials = {
      k8s-backups = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      wal-g       = { access_key = "", secret_key = "" }
      loki        = { access_key = "mock-loki", secret_key = "mock-loki-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_a_short_secret" {
  command = plan

  variables {
    bucket_credentials = {
      k8s-backups = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      wal-g       = { access_key = "mock-walg", secret_key = "short" }
      loki        = { access_key = "mock-loki", secret_key = "mock-loki-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_duplicate_access_keys" {
  command = plan

  variables {
    bucket_credentials = {
      k8s-backups = { access_key = "mock-shared", secret_key = "mock-backups-secret" }
      wal-g       = { access_key = "mock-shared", secret_key = "mock-walg-secret" }
      loki        = { access_key = "mock-loki", secret_key = "mock-loki-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_the_admin_access_key" {
  command = plan

  variables {
    bucket_credentials = {
      k8s-backups = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      wal-g       = { access_key = "mockadmin", secret_key = "mock-walg-secret" }
      loki        = { access_key = "mock-loki", secret_key = "mock-loki-secret" }
    }
  }

  expect_failures = [var.bucket_credentials]
}

run "rejects_a_missing_required_bucket" {
  command = plan

  variables {
    buckets = {
      k8s-backups = { quota_bytes = 53687091200, versioning = true }
      loki        = { quota_bytes = 10737418240 }
    }
    bucket_credentials = {
      k8s-backups = { access_key = "mock-backups", secret_key = "mock-backups-secret" }
      loki        = { access_key = "mock-loki", secret_key = "mock-loki-secret" }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_a_zero_quota" {
  command = plan

  variables {
    buckets = {
      k8s-backups = { quota_bytes = 53687091200, versioning = true }
      wal-g       = { quota_bytes = 0 }
      loki        = { quota_bytes = 10737418240 }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_a_fractional_quota" {
  command = plan

  variables {
    buckets = {
      k8s-backups = { quota_bytes = 53687091200, versioning = true }
      wal-g       = { quota_bytes = 1.5 }
      loki        = { quota_bytes = 10737418240 }
    }
  }

  expect_failures = [var.buckets]
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
