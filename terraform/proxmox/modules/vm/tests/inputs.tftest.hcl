mock_provider "proxmox" {}

variables {
  node          = "fixture"
  storage       = "local-lvm"
  bridge        = "vmbr0"
  id            = 1001
  name          = "fixture-haos"
  image_file_id = "local:iso/haos_ova-18.3.qcow2.img"
}

run "unknown_bios_is_rejected" {
  command = plan
  variables { bios = "uefi" }
  expect_failures = [var.bios]
}

run "unknown_scsi_controller_is_rejected" {
  command = plan
  variables { scsi_hardware = "virtio" }
  expect_failures = [var.scsi_hardware]
}

run "unknown_network_model_is_rejected" {
  command = plan
  variables { network_devices = [{ model = "intel" }] }
  expect_failures = [var.network_devices]
}

run "unknown_os_type_is_rejected" {
  command = plan
  variables { os_type = "linux" }
  expect_failures = [var.os_type]
}

run "unknown_efi_disk_type_is_rejected" {
  command = plan
  variables { efi_disk = { type = "8m" } }
  expect_failures = [var.efi_disk]
}

run "zero_sockets_are_rejected" {
  command = plan
  variables { cpu = { sockets = 0 } }
  expect_failures = [var.cpu]
}

run "hotplugged_processors_cannot_exceed_capacity" {
  command = plan
  variables { cpu = { cores = 2, sockets = 2, hotplugged = 5 } }
  expect_failures = [var.cpu]
}

run "ballooning_cannot_exceed_dedicated_memory" {
  command = plan
  variables { memory = { dedicated = 4096, floating = 8192 } }
  expect_failures = [var.memory]
}

run "negative_shared_memory_is_rejected" {
  command = plan
  variables { memory = { shared = -1 } }
  expect_failures = [var.memory]
}

run "unknown_agent_type_is_rejected" {
  command = plan
  variables { agent = { type = "serial" } }
  expect_failures = [var.agent]
}

run "unknown_display_type_is_rejected" {
  command = plan
  variables { vga = { type = "gpu" } }
  expect_failures = [var.vga]
}

run "empty_network_devices_are_rejected" {
  command = plan
  variables { network_devices = [] }
  expect_failures = [var.network_devices]
}

run "network_queue_count_is_bounded" {
  command = plan
  variables { network_devices = [{ queues = 65 }] }
  expect_failures = [var.network_devices]
}

run "unknown_boot_disk_cache_is_rejected" {
  command = plan
  variables { disk = { cache = "fast" } }
  expect_failures = [var.disk]
}

run "negative_timeout_is_rejected" {
  command = plan
  variables { timeouts = { reboot = -1 } }
  expect_failures = [var.timeouts]
}

run "fractional_id_is_rejected" {
  command = plan
  variables { id = 1001.5 }
  expect_failures = [var.id]
}

run "unmanaged_id_is_rejected" {
  command = plan
  variables { id = 999 }
  expect_failures = [var.id]
}

run "zero_cpu_is_rejected" {
  command = plan
  variables { cpu = { cores = 0 } }
  expect_failures = [var.cpu]
}

run "fractional_ram_is_rejected" {
  command = plan
  variables { memory = { dedicated = 2048.5 } }
  expect_failures = [var.memory]
}

run "undersized_haos_disk_is_rejected" {
  command = plan
  variables { disk = { size = 31 } }
  expect_failures = [var.disk]
}

run "invalid_vlan_is_rejected" {
  command = plan
  variables { network_devices = [{ vlan_id = 4095 }] }
  expect_failures = [var.network_devices]
}

run "non_qcow2_image_is_rejected" {
  command = plan
  variables { image_file_id = "local:iso/haos.img" }
  expect_failures = [var.image_file_id]
}

run "compressed_image_is_rejected" {
  command = plan
  variables { image_file_id = "local:import/haos_ova-18.3.qcow2.xz" }
  expect_failures = [var.image_file_id]
}

run "additional_disk_interface_cannot_use_boot_slot" {
  command = plan
  variables {
    additional_disks = [{ interface = "scsi0", size = 32 }]
  }
  expect_failures = [var.additional_disks]
}

run "additional_disk_cannot_use_a_custom_boot_slot" {
  command = plan
  variables {
    disk             = { interface = "sata1" }
    additional_disks = [{ interface = "sata1", size = 32 }]
  }
  expect_failures = [var.additional_disks]
}

run "invalid_boot_disk_interface_is_rejected" {
  command = plan
  variables { disk = { interface = "scsi31" } }
  expect_failures = [var.disk]
}

run "additional_disk_cannot_use_two_image_sources" {
  command = plan
  variables {
    additional_disks = [{
      interface   = "scsi1"
      file_id     = "local:iso/data.qcow2.img"
      import_from = "local:import/data.qcow2"
    }]
  }
  expect_failures = [var.additional_disks]
}

run "additional_disk_requires_one_source" {
  command = plan
  variables {
    additional_disks = [{ interface = "scsi1" }]
  }
  expect_failures = [var.additional_disks]
}

run "additional_disk_size_must_be_positive_integer" {
  command = plan
  variables {
    additional_disks = [{ interface = "scsi1", size = 0 }]
  }
  expect_failures = [var.additional_disks]
}

run "additional_disk_discard_mode_is_restricted" {
  command = plan
  variables {
    additional_disks = [{ interface = "scsi1", size = 32, discard = "maybe" }]
  }
  expect_failures = [var.additional_disks]
}

run "additional_disk_queues_need_two_or_more" {
  command = plan
  variables {
    additional_disks = [{ interface = "scsi1", size = 32, queues = 1 }]
  }
  expect_failures = [var.additional_disks]
}

run "additional_disk_interfaces_must_be_unique" {
  command = plan
  variables {
    additional_disks = [
      { interface = "scsi1", size = 32 },
      { interface = "scsi1", size = 64 },
    ]
  }
  expect_failures = [var.additional_disks]
}
