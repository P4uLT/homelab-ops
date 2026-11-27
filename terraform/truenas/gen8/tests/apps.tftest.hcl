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
  rustfs_app_api_port       = 30292
  rustfs_app_web_port       = 30293
  rustfs_app_certificate_id = 202
  rustfs_app_access_key     = "mockadmin"
  rustfs_app_secret_key     = "mocksecret"
}

run "plans_the_gated_application" {
  command = plan

  variables {
    # An operator can leave the console enabled in local tfvars.
    rustfs_app_web_published = false
  }

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
      !can(jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.web_port.host_ips) &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).run_as.user == 568
    )
    error_message = "The app values must follow the chart contract: one host-path disk, a published API port, and an exposed WebUI."
  }
}

run "publishes_the_console_port_when_asked" {
  command = plan

  variables {
    rustfs_app_web_published = true
    rustfs_app_web_port      = 30294
  }

  assert {
    condition = (
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.web_port.bind_mode == "published" &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.web_port.port_number == 30294 &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.api_port.bind_mode == "published" &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.api_port.port_number == 30292 &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.api_port.host_ips == ["0.0.0.0"] &&
      jsondecode(nonsensitive(truenas_app.rustfs[0].values)).network.web_port.host_ips == ["0.0.0.0"]
    )
    error_message = "The publish flag must map the console port to a published bind with the wildcard host."
  }
}
