mock_provider "truenas" {
  mock_data "truenas_service" {
    defaults = { running = true, enabled = true }
  }

  mock_resource "truenas_dataset" {
    defaults = { mountpoint = "/mnt/tank/rustfs" }
  }
}

variables {
  truenas_host     = "nas.example.invalid"
  truenas_api_key  = "mock-only"
  state_passphrase = "mock-only-passphrase"
  datasets = {
    rustfs = { name = "tank/rustfs", share_type = "APPS" }
  }

  rustfs_app_enabled        = true
  rustfs_app_version        = "1.1.46"
  rustfs_app_certificate_id = 1
  rustfs_app_api_bind_ip    = "192.0.2.10"
  rustfs_app_access_key     = "mockadmin"
  rustfs_app_secret_key     = "mocksecret"
}

run "rejects_an_enabled_app_without_its_dataset" {
  command = plan

  variables {
    datasets = {
      iso = { name = "tank/iso" }
    }
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_an_enabled_app_on_a_misnamed_dataset" {
  command = plan

  variables {
    datasets = {
      rustfs = { name = "tank/object-store" }
    }
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_a_missing_version" {
  command = plan

  variables {
    rustfs_app_version = null
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_a_floating_latest_version" {
  command = plan

  variables {
    rustfs_app_version = "latest"
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_a_missing_access_key" {
  command = plan

  variables {
    rustfs_app_access_key = null
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_a_short_secret_key" {
  command = plan

  variables {
    rustfs_app_secret_key = "short"
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_a_missing_certificate" {
  command = plan

  variables {
    rustfs_app_certificate_id = null
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_a_missing_api_bind_address" {
  command = plan

  variables {
    rustfs_app_api_bind_ip = null
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_a_wildcard_api_bind_address" {
  command = plan

  variables {
    rustfs_app_api_bind_ip = "0.0.0.0"
  }

  expect_failures = [var.rustfs_app_enabled]
}

run "rejects_equal_app_ports" {
  command = plan

  variables {
    rustfs_app_web_port = 30292
  }

  expect_failures = [var.rustfs_app_api_port]
}

run "rejects_an_out_of_range_api_port" {
  command = plan

  variables {
    rustfs_app_api_port = 70000
  }

  expect_failures = [var.rustfs_app_api_port]
}
