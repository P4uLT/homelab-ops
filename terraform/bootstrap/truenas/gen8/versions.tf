terraform {
  required_version = "1.12.6"

  required_providers {
    truenas = {
      source  = "truenas/truenas"
      version = "1.9.3"
    }
  }
}

provider "truenas" {
  endpoint = "wss://${var.truenas_host}/api/current"
  api_key  = var.truenas_api_key
  ca_cert  = var.truenas_ca_cert
}
