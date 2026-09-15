# The jarvis root. One root per PVE server, named after it. It
# instantiates the Packer golden images as LXC workloads on the node.

terraform {
  # Exact pin, in step with the opentofu entry in mise.toml.
  required_version = "1.12.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.99.0"
    }
  }
}

provider "proxmox" {
  # The endpoint and the token come from the git-ignored
  # jarvis.local.auto.tfvars, which tofu loads itself.
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token

  # PVE ships a self-signed certificate.
  insecure = true
}
