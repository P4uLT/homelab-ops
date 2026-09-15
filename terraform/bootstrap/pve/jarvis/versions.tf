terraform {
  # Exact pin, in step with the roots.
  required_version = "1.12.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.99.0"
    }
  }
}
