terraform {
  required_version = "1.12.6"

  required_providers {
    rustfs = {
      source  = "caberdo/rustfs"
      version = "~> 0.10"
    }
  }
}

provider "rustfs" {
  endpoint   = var.rustfs_endpoint
  access_key = var.rustfs_access_key
  secret_key = var.rustfs_secret_key
}
