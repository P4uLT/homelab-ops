resource "truenas_docker_config" "gen8" {
  count = var.rustfs_app_enabled ? 1 : 0
  pool  = "tank"
}

resource "truenas_catalog_config" "gen8" {
  count            = var.rustfs_app_enabled ? 1 : 0
  preferred_trains = ["stable", "community"]

  depends_on = [truenas_docker_config.gen8]
}

resource "truenas_app" "rustfs" {
  count       = var.rustfs_app_enabled ? 1 : 0
  name        = "rustfs"
  catalog_app = "rustfs"
  train       = "community"
  version     = var.rustfs_app_version
  running     = true
  values = jsonencode({
    rustfs = {
      deployment_mode = "snsd"
      access_key      = var.rustfs_app_access_key
      secret_key      = var.rustfs_app_secret_key
    }
    network = {
      certificate_id = var.rustfs_app_certificate_id
      api_port = {
        bind_mode   = "published"
        port_number = var.rustfs_app_api_port
        host_ips    = [{ host_ip = var.rustfs_app_api_bind_ip }]
      }
      web_port = { bind_mode = "exposed", port_number = var.rustfs_app_web_port }
    }
    run_as = { user = 568, group = 568 }
    storage = {
      data_disks = [{
        type             = "host_path"
        host_path_config = { host_path = "/mnt/${var.rustfs_app_dataset}" }
      }]
    }
  })

  depends_on = [truenas_catalog_config.gen8, module.dataset]
}
