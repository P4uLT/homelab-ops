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
  rustfs_app_version        = "1.1.47"
  rustfs_app_certificate_id = 202
  rustfs_app_access_key     = "mockadmin"
  rustfs_app_secret_key     = "mocksecret"
}

run "plans_the_gated_application" {
  command = plan

  assert {
    condition = (
      truenas_docker_config.gen8[0].pool == "tank" &&
      toset(truenas_catalog_config.gen8[0].preferred_trains) == toset(["stable", "community"]) &&
      length(truenas_app.rustfs) == 1 &&
      truenas_app.rustfs[0].name == "rustfs" &&
      truenas_app.rustfs[0].catalog_app == "rustfs" &&
      truenas_app.rustfs[0].train == "community" &&
      truenas_app.rustfs[0].version == "1.1.47" &&
      issensitive(truenas_app.rustfs[0].values) &&
      truenas_app.rustfs[0].running
    )
    error_message = "The gate must install the pinned RustFS app with its Docker and catalog settings."
  }

  assert {
    condition = (
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).rustfs.deployment_mode == "snsd" &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).storage.data_disks[0].host_path_config.path == "/mnt/tank/rustfs" &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.api_port.port_number == 30292 &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.web_port.port_number == 30293 &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.certificate_id == 202 &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.api_port.bind_mode == "published" &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.api_port.host_ips[0] == "0.0.0.0" &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.web_port.bind_mode == "exposed" &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).run_as.user == 568
    )
    error_message = "The app values must follow the chart contract: one host-path disk, a published API port, and an exposed WebUI."
  }
}
