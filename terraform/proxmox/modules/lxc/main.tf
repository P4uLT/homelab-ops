# Shared LXC module. One instance per container workload: a container
# cloned from a golden image, started, addressed over DHCP. The node
# facts come from the calling root; the module owns none.
#
# IP policy: DHCP is the default. A static value only ever comes from a
# git-ignored tfvars file, never a tracked one.
#
# The boot, VLAN, mount point, and MAC patterns are adapted from
# trfore/terraform-bpg-proxmox (Apache-2.0).

resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node
  vm_id         = var.id
  description   = var.description
  unprivileged  = var.unprivileged
  started       = var.started
  start_on_boot = var.start_on_boot
  protection    = var.protection
  tags          = var.tags

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ipv4.address
        gateway = var.ipv4.gateway
      }
    }
  }

  cpu {
    cores = var.cpu
  }

  memory {
    dedicated = var.ram
    swap      = var.swap
  }

  disk {
    datastore_id = var.storage
    size         = var.disk
  }

  dynamic "mount_point" {
    for_each = var.mountpoints != null ? var.mountpoints : []
    content {
      volume    = mount_point.value.volume
      path      = mount_point.value.path
      size      = mount_point.value.size
      backup    = mount_point.value.backup
      read_only = mount_point.value.read_only
    }
  }

  network_interface {
    name        = var.interface_name
    bridge      = var.bridge
    vlan_id     = var.vlan_id
    mac_address = var.mac_address
  }

  features {
    nesting = var.nesting
    keyctl  = var.keyctl
  }

  operating_system {
    template_file_id = var.template
    type             = var.os_type
  }

  dynamic "startup" {
    for_each = var.startup != null ? [var.startup] : []
    content {
      order      = startup.value.order
      up_delay   = startup.value.up_delay
      down_delay = startup.value.down_delay
    }
  }

  # Wait for the guest to report an address. A Docker image also brings
  # docker0 up, and its 172.17.0.1 can satisfy the wait before the
  # container interface holds a DHCP lease: ct_ipv4 stays null until
  # the guest reports one there.
  wait_for_ip {
    ipv4 = var.wait_for_ipv4
  }
}
