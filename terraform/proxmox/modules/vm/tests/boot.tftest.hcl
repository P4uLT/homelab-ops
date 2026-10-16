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
    cpu             = null
    memory          = null
    disk            = null
    protection      = null
    prevent_destroy = null
    bios            = null
    boot_order      = null
    scsi_hardware   = null
    agent           = null
    efi_disk        = null
    network_devices = null
    os_type         = null
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.cpu[0].cores == 2 &&
      proxmox_virtual_environment_vm.this.memory[0].dedicated == 4096 &&
      proxmox_virtual_environment_vm.this.disk[0].size == 64 &&
      proxmox_virtual_environment_vm.this.disk[0].interface == "scsi0" &&
      proxmox_virtual_environment_vm.this.bios == "ovmf" &&
      proxmox_virtual_environment_vm.this.boot_order == tolist(["scsi0"]) &&
      proxmox_virtual_environment_vm.this.scsi_hardware == "virtio-scsi-single" &&
      proxmox_virtual_environment_vm.this.agent[0].enabled &&
      proxmox_virtual_environment_vm.this.efi_disk[0].type == "4m" &&
      !proxmox_virtual_environment_vm.this.efi_disk[0].pre_enrolled_keys &&
      proxmox_virtual_environment_vm.this.network_device[0].model == "virtio" &&
      proxmox_virtual_environment_vm.this.operating_system[0].type == "l26" &&
      proxmox_virtual_environment_vm.this.protection
    )
    error_message = "Null optional inputs must retain the appliance hardware and protection defaults."
  }
}

run "explicit_hardware_and_startup_are_preserved" {
  command = plan
  variables {
    cpu             = { cores = 4 }
    memory          = { dedicated = 8192 }
    disk            = { size = 96 }
    network_devices = [{ vlan_id = 10 }]
    started         = false
    start_on_boot   = false
    startup         = { order = 5, up_delay = 30, down_delay = 60 }
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

run "boot_and_guest_settings_are_configurable" {
  command = plan
  variables {
    bios             = "seabios"
    boot_order       = ["net0", "sata0"]
    scsi_hardware    = "lsi"
    disk             = { interface = "sata0" }
    agent            = { enabled = false }
    efi_disk         = { enabled = false }
    network_devices  = [{ model = "e1000" }]
    os_type          = "other"
    additional_disks = [{ interface = "scsi1", size = 32 }]
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.bios == "seabios" &&
      proxmox_virtual_environment_vm.this.boot_order == tolist(["net0", "sata0"]) &&
      proxmox_virtual_environment_vm.this.scsi_hardware == "lsi" &&
      proxmox_virtual_environment_vm.this.disk[0].interface == "sata0" &&
      proxmox_virtual_environment_vm.this.disk[1].interface == "scsi1" &&
      !proxmox_virtual_environment_vm.this.agent[0].enabled &&
      length(proxmox_virtual_environment_vm.this.efi_disk) == 0 &&
      proxmox_virtual_environment_vm.this.network_device[0].model == "e1000" &&
      proxmox_virtual_environment_vm.this.operating_system[0].type == "other"
    )
    error_message = "Explicit boot, guest, and network settings must replace the appliance defaults."
  }
}

run "additional_disks_can_use_the_old_boot_slot" {
  command = plan
  variables {
    disk             = { interface = "sata0" }
    additional_disks = [{ interface = "scsi0", size = 32 }]
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.disk[0].interface == "sata0" &&
      proxmox_virtual_environment_vm.this.disk[1].interface == "scsi0"
    )
    error_message = "Only the selected boot disk interface must be reserved."
  }
}

run "boot_order_defaults_to_the_selected_disk" {
  command = plan
  variables {
    disk = { interface = "virtio0" }
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.disk[0].interface == "virtio0" &&
      proxmox_virtual_environment_vm.this.boot_order == tolist(["virtio0"])
    )
    error_message = "The default boot order must follow the selected boot disk interface."
  }
}

run "efi_disk_settings_are_configurable" {
  command = plan
  variables {
    efi_disk = {
      datastore_id      = "efi-storage"
      type              = "2m"
      pre_enrolled_keys = false
    }
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.efi_disk[0].datastore_id == "efi-storage" &&
      proxmox_virtual_environment_vm.this.efi_disk[0].type == "2m" &&
      !proxmox_virtual_environment_vm.this.efi_disk[0].pre_enrolled_keys
    )
    error_message = "Explicit EFI settings must reach the provider."
  }
}

run "secure_boot_keys_can_be_enabled" {
  command = plan
  variables {
    efi_disk = { pre_enrolled_keys = true }
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.efi_disk[0].datastore_id == "local-lvm" &&
      proxmox_virtual_environment_vm.this.efi_disk[0].type == "4m" &&
      proxmox_virtual_environment_vm.this.efi_disk[0].pre_enrolled_keys
    )
    error_message = "EFI overrides must preserve omitted defaults and allow pre-enrolled keys."
  }
}

run "disable_protection_for_deliberate_replacement" {
  command = apply
  variables {
    protection      = false
    prevent_destroy = false
  }
  assert {
    condition     = !proxmox_virtual_environment_vm.this.protection
    error_message = "The caller must be able to disable Proxmox deletion protection."
  }
}

run "replacement_is_allowed_after_disabling_both_guards" {
  command = plan
  variables {
    protection      = false
    prevent_destroy = false
  }
  plan_options {
    replace = [proxmox_virtual_environment_vm.this]
  }
  assert {
    condition     = !proxmox_virtual_environment_vm.this.protection
    error_message = "A deliberate replacement must keep Proxmox deletion protection disabled."
  }
}
