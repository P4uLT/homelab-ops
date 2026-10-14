mock_provider "proxmox" {}

variables {
  node          = "fixture"
  storage       = "local-lvm"
  bridge        = "vmbr0"
  id            = 1001
  name          = "fixture-haos"
  image_file_id = "local:iso/haos_ova-18.3.qcow2.img"
}

run "haos_boots_from_imported_disk_with_persistent_uefi" {
  command = plan
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.bios == "ovmf" &&
      try(proxmox_virtual_environment_vm.this.efi_disk[0].type == "4m", false) &&
      try(!proxmox_virtual_environment_vm.this.efi_disk[0].pre_enrolled_keys, false)
    )
    error_message = "HAOS needs persistent UEFI without Secure Boot keys."
  }
  assert {
    condition = (
      try(proxmox_virtual_environment_vm.this.disk[0].file_id == var.image_file_id, false) &&
      proxmox_virtual_environment_vm.this.disk[0].import_from == null &&
      try(proxmox_virtual_environment_vm.this.disk[0].interface == "scsi0", false) &&
      try(proxmox_virtual_environment_vm.this.disk[0].size == 64, false) &&
      proxmox_virtual_environment_vm.this.boot_order == tolist(["scsi0"])
    )
    error_message = "The boot disk must import the downloaded image through the provider SSH path."
  }
  assert {
    condition = (
      try(proxmox_virtual_environment_vm.this.cpu[0].cores == 2, false) &&
      try(proxmox_virtual_environment_vm.this.memory[0].dedicated == 4096, false) &&
      try(proxmox_virtual_environment_vm.this.network_device[0].model == "virtio", false) &&
      try(proxmox_virtual_environment_vm.this.network_device[0].bridge == "vmbr0", false) &&
      try(proxmox_virtual_environment_vm.this.agent[0].enabled, false)
    )
    error_message = "HAOS needs the approved hardware and guest-agent channel."
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.protection &&
      length(proxmox_virtual_environment_vm.this.initialization) == 0
    )
    error_message = "Protect the appliance and omit cloud-init."
  }
}

run "additional_disks_are_attached_after_the_boot_disk" {
  command = plan
  variables {
    additional_disks = [
      {
        interface = "scsi1"
        size      = 32
        backup    = false
        discard   = "on"
        iothread  = true
        queues    = 4
      },
      {
        interface = "scsi2"
        file_id   = "local:iso/data.qcow2.img"
      },
    ]
  }
  assert {
    condition = (
      length(proxmox_virtual_environment_vm.this.disk) == 3 &&
      proxmox_virtual_environment_vm.this.disk[1].interface == "scsi1" &&
      proxmox_virtual_environment_vm.this.disk[1].datastore_id == var.storage &&
      proxmox_virtual_environment_vm.this.disk[1].size == 32 &&
      !proxmox_virtual_environment_vm.this.disk[1].backup &&
      proxmox_virtual_environment_vm.this.disk[1].discard == "on" &&
      proxmox_virtual_environment_vm.this.disk[1].iothread &&
      proxmox_virtual_environment_vm.this.disk[1].queues == 4 &&
      proxmox_virtual_environment_vm.this.disk[2].interface == "scsi2" &&
      proxmox_virtual_environment_vm.this.disk[2].file_id == "local:iso/data.qcow2.img"
    )
    error_message = "Additional VM disks must map to provider disk blocks after scsi0."
  }
}

run "null_hardware_inputs_keep_haos_defaults" {
  command = plan
  variables {
    cpu  = null
    ram  = null
    disk = null
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.cpu[0].cores == 2 &&
      proxmox_virtual_environment_vm.this.memory[0].dedicated == 4096 &&
      proxmox_virtual_environment_vm.this.disk[0].size == 64
    )
    error_message = "Null optional hardware inputs must retain the appliance defaults."
  }
}

run "explicit_hardware_and_startup_are_preserved" {
  command = plan
  variables {
    cpu           = 4
    ram           = 8192
    disk          = 96
    vlan_id       = 10
    started       = false
    start_on_boot = false
    startup       = { order = 5, up_delay = 30, down_delay = 60 }
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.cpu[0].cores == 4 &&
      proxmox_virtual_environment_vm.this.memory[0].dedicated == 8192 &&
      proxmox_virtual_environment_vm.this.disk[0].size == 96 &&
      proxmox_virtual_environment_vm.this.network_device[0].vlan_id == 10 &&
      !proxmox_virtual_environment_vm.this.started &&
      !proxmox_virtual_environment_vm.this.on_boot &&
      proxmox_virtual_environment_vm.this.startup[0].order == 5 &&
      proxmox_virtual_environment_vm.this.startup[0].up_delay == 30 &&
      proxmox_virtual_environment_vm.this.startup[0].down_delay == 60
    )
    error_message = "Explicit hardware, network and startup inputs must be preserved."
  }
}
