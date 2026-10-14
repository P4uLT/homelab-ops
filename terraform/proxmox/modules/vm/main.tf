resource "proxmox_virtual_environment_vm" "this" {
  node_name   = var.node
  vm_id       = var.id
  name        = var.name
  description = var.description
  tags        = var.tags

  bios          = "ovmf"
  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"
  protection    = true
  started       = var.started
  on_boot       = var.start_on_boot

  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu
  }

  memory {
    dedicated = var.ram
  }

  disk {
    datastore_id = var.storage
    file_id      = var.image_file_id
    interface    = "scsi0"
    size         = var.disk
  }

  dynamic "disk" {
    for_each = var.additional_disks
    content {
      datastore_id = coalesce(disk.value.datastore_id, var.storage)
      file_id      = disk.value.file_id
      import_from  = disk.value.import_from
      interface    = disk.value.interface
      size         = disk.value.size
      backup       = disk.value.backup
      discard      = disk.value.discard
      iothread     = disk.value.iothread
      queues       = disk.value.queues
    }
  }

  efi_disk {
    datastore_id      = var.storage
    type              = "4m"
    pre_enrolled_keys = false
  }

  network_device {
    bridge      = var.bridge
    model       = "virtio"
    vlan_id     = var.vlan_id
    mac_address = var.mac_address
  }

  operating_system {
    type = "l26"
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
    # Replacing the source image must not discard appliance data.
    prevent_destroy = true
  }
}
