resource "proxmox_virtual_environment_vm" "this" {
  node_name   = var.node
  vm_id       = var.id
  name        = var.name
  description = var.description
  tags        = var.tags

  bios                = var.bios
  machine             = var.machine
  boot_order          = var.boot_order != null ? var.boot_order : [var.disk.interface]
  scsi_hardware       = var.scsi_hardware
  hotplug             = length(var.hotplug) == 0 ? "0" : join(",", sort(var.hotplug))
  protection          = var.protection
  started             = var.started
  on_boot             = var.start_on_boot
  reboot_after_update = var.reboot_after_update

  timeout_create      = var.timeouts.create
  timeout_migrate     = var.timeouts.migrate
  timeout_reboot      = var.timeouts.reboot
  timeout_shutdown_vm = var.timeouts.shutdown_vm
  timeout_start_vm    = var.timeouts.start_vm
  timeout_stop_vm     = var.timeouts.stop_vm

  agent {
    enabled = var.agent.enabled
    type    = var.agent.type
    timeout = var.agent.timeout
    trim    = var.agent.trim

    dynamic "wait_for_ip" {
      for_each = var.agent.wait_for_ip == null ? [] : [var.agent.wait_for_ip]
      content {
        disabled = wait_for_ip.value.disabled
        ipv4     = wait_for_ip.value.ipv4
        ipv6     = wait_for_ip.value.ipv6
      }
    }
  }

  cpu {
    cores      = var.cpu.cores
    sockets    = var.cpu.sockets
    type       = var.cpu.type
    hotplugged = var.cpu.hotplugged
    numa       = var.cpu.numa
  }

  memory {
    dedicated = var.memory.dedicated
    floating  = var.memory.floating
    shared    = var.memory.shared
  }

  disk {
    datastore_id = coalesce(var.disk.datastore_id, var.storage)
    file_id      = var.image_file_id
    interface    = var.disk.interface
    size         = var.disk.size
    file_format  = var.disk.file_format
    cache        = var.disk.cache
    backup       = var.disk.backup
    discard      = var.disk.discard
    iothread     = var.disk.iothread
    ssd          = var.disk.ssd
    queues       = var.disk.queues
  }

  dynamic "disk" {
    for_each = var.additional_disks
    content {
      datastore_id = coalesce(disk.value.datastore_id, var.storage)
      file_id      = disk.value.file_id
      import_from  = disk.value.import_from
      interface    = disk.value.interface
      size         = disk.value.size
      file_format  = disk.value.file_format
      cache        = disk.value.cache
      backup       = disk.value.backup
      discard      = disk.value.discard
      iothread     = disk.value.iothread
      ssd          = disk.value.ssd
      queues       = disk.value.queues
    }
  }

  dynamic "efi_disk" {
    for_each = var.efi_disk.enabled ? [var.efi_disk] : []
    content {
      datastore_id      = coalesce(efi_disk.value.datastore_id, var.storage)
      file_format       = efi_disk.value.file_format
      type              = efi_disk.value.type
      pre_enrolled_keys = efi_disk.value.pre_enrolled_keys
    }
  }

  dynamic "network_device" {
    for_each = var.network_devices
    content {
      bridge       = coalesce(network_device.value.bridge, var.bridge)
      model        = network_device.value.model
      vlan_id      = network_device.value.vlan_id
      mac_address  = network_device.value.mac_address
      firewall     = network_device.value.firewall
      disconnected = network_device.value.disconnected
      queues       = network_device.value.queues
      mtu          = network_device.value.mtu
      rate_limit   = network_device.value.rate_limit
    }
  }

  dynamic "vga" {
    for_each = var.vga == null ? [] : [var.vga]
    content {
      type   = vga.value.type
      memory = vga.value.memory
    }
  }

  operating_system {
    type = var.os_type
  }

  dynamic "startup" {
    for_each = var.startup != null ? [var.startup] : []
    content {
      order      = startup.value.order
      up_delay   = startup.value.up_delay
      down_delay = startup.value.down_delay
    }
  }

  lifecycle {
    prevent_destroy = var.prevent_destroy
  }
}
