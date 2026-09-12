# One LXC workload: a container cloned from a golden image, started,
# addressed by DHCP. The repo keeps IP addresses out of tracked files,
# so DHCP is the only addressing this module offers.

resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.node
  vm_id        = var.id
  unprivileged = var.unprivileged
  started      = var.started
  tags         = var.tags

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  cpu {
    cores = var.cpu
  }

  memory {
    dedicated = var.ram
  }

  disk {
    datastore_id = var.storage
    size         = var.disk
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  features {
    nesting = var.nesting
    keyctl  = var.keyctl
  }

  operating_system {
    template_file_id = var.template
    type             = var.os_type
  }
}
