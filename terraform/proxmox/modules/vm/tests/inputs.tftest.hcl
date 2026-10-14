mock_provider "proxmox" {}

variables {
  node          = "fixture"
  storage       = "local-lvm"
  bridge        = "vmbr0"
  id            = 1001
  name          = "fixture-haos"
  image_file_id = "local:iso/haos_ova-18.3.qcow2.img"
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
  variables { cpu = 0 }
  expect_failures = [var.cpu]
}

run "fractional_ram_is_rejected" {
  command = plan
  variables { ram = 2048.5 }
  expect_failures = [var.ram]
}

run "undersized_haos_disk_is_rejected" {
  command = plan
  variables { disk = 31 }
  expect_failures = [var.disk]
}

run "invalid_vlan_is_rejected" {
  command = plan
  variables { vlan_id = 4095 }
  expect_failures = [var.vlan_id]
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
