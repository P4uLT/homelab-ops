mock_provider "proxmox" {}

variables {
  node          = "fixture"
  storage       = "local-lvm"
  bridge        = "vmbr0"
  id            = 1001
  name          = "fixture-settings"
  image_file_id = "local:iso/haos_ova-18.3.qcow2.img"
}

run "empty_and_null_object_fields_keep_defaults" {
  command = plan
  variables {
    cpu             = { cores = null, sockets = null, type = null, hotplugged = null, numa = null }
    memory          = { dedicated = null, floating = null, shared = null }
    disk            = {}
    agent           = {}
    network_devices = [{}]
    timeouts        = {}
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.cpu[0].cores == 2 &&
      proxmox_virtual_environment_vm.this.cpu[0].sockets == 1 &&
      proxmox_virtual_environment_vm.this.cpu[0].type == "qemu64" &&
      proxmox_virtual_environment_vm.this.cpu[0].hotplugged == 0 &&
      !proxmox_virtual_environment_vm.this.cpu[0].numa &&
      proxmox_virtual_environment_vm.this.memory[0].dedicated == 4096 &&
      proxmox_virtual_environment_vm.this.memory[0].floating == 0 &&
      proxmox_virtual_environment_vm.this.memory[0].shared == 0 &&
      proxmox_virtual_environment_vm.this.disk[0].size == 64 &&
      proxmox_virtual_environment_vm.this.disk[0].interface == "scsi0" &&
      proxmox_virtual_environment_vm.this.agent[0].enabled &&
      proxmox_virtual_environment_vm.this.agent[0].timeout == "15m" &&
      proxmox_virtual_environment_vm.this.network_device[0].model == "virtio" &&
      proxmox_virtual_environment_vm.this.timeout_create == 1800 &&
      proxmox_virtual_environment_vm.this.timeout_stop_vm == 300
    )
    error_message = "Empty objects and null fields must retain the existing VM and provider defaults."
  }
}

run "cpu_memory_and_reboot_settings_are_preserved" {
  command = plan
  variables {
    cpu = {
      cores      = 4
      sockets    = 2
      type       = "host"
      hotplugged = 6
      numa       = true
    }
    memory              = { dedicated = 8192, floating = 4096, shared = 32 }
    machine             = "q35"
    reboot_after_update = false
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.cpu[0].cores == 4 &&
      proxmox_virtual_environment_vm.this.cpu[0].sockets == 2 &&
      proxmox_virtual_environment_vm.this.cpu[0].type == "host" &&
      proxmox_virtual_environment_vm.this.cpu[0].hotplugged == 6 &&
      proxmox_virtual_environment_vm.this.cpu[0].numa &&
      proxmox_virtual_environment_vm.this.memory[0].dedicated == 8192 &&
      proxmox_virtual_environment_vm.this.memory[0].floating == 4096 &&
      proxmox_virtual_environment_vm.this.memory[0].shared == 32 &&
      proxmox_virtual_environment_vm.this.machine == "q35" &&
      !proxmox_virtual_environment_vm.this.reboot_after_update
    )
    error_message = "CPU, memory, machine, and reboot inputs must reach the provider unchanged."
  }
}

run "disk_tuning_is_preserved" {
  command = plan
  variables {
    disk = {
      size        = 96
      interface   = "scsi2"
      file_format = "raw"
      cache       = "writeback"
      discard     = "on"
      iothread    = true
      ssd         = true
      backup      = false
      queues      = 4
    }
    additional_disks = [{
      interface   = "scsi0"
      size        = 32
      file_format = "qcow2"
      cache       = "writethrough"
      ssd         = true
    }]
    efi_disk = { file_format = "raw" }
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.disk[0].size == 96 &&
      proxmox_virtual_environment_vm.this.disk[0].interface == "scsi2" &&
      proxmox_virtual_environment_vm.this.boot_order == tolist(["scsi2"]) &&
      proxmox_virtual_environment_vm.this.disk[0].file_format == "raw" &&
      proxmox_virtual_environment_vm.this.disk[0].cache == "writeback" &&
      proxmox_virtual_environment_vm.this.disk[0].discard == "on" &&
      proxmox_virtual_environment_vm.this.disk[0].iothread &&
      proxmox_virtual_environment_vm.this.disk[0].ssd &&
      !proxmox_virtual_environment_vm.this.disk[0].backup &&
      proxmox_virtual_environment_vm.this.disk[0].queues == 4 &&
      proxmox_virtual_environment_vm.this.disk[1].interface == "scsi0" &&
      proxmox_virtual_environment_vm.this.disk[1].cache == "writethrough" &&
      proxmox_virtual_environment_vm.this.disk[1].file_format == "qcow2" &&
      proxmox_virtual_environment_vm.this.disk[1].ssd &&
      proxmox_virtual_environment_vm.this.efi_disk[0].file_format == "raw"
    )
    error_message = "Boot and additional disks must preserve explicit tuning and reserve only the boot slot."
  }
}

run "agent_settings_are_preserved" {
  command = plan
  variables {
    agent = {
      type        = "isa"
      timeout     = "30s"
      trim        = true
      wait_for_ip = { ipv4 = true }
    }
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.agent[0].enabled &&
      proxmox_virtual_environment_vm.this.agent[0].type == "isa" &&
      proxmox_virtual_environment_vm.this.agent[0].timeout == "30s" &&
      proxmox_virtual_environment_vm.this.agent[0].trim &&
      proxmox_virtual_environment_vm.this.agent[0].wait_for_ip[0].ipv4 &&
      !proxmox_virtual_environment_vm.this.agent[0].wait_for_ip[0].ipv6
    )
    error_message = "Agent options must preserve explicit values and omitted nested defaults."
  }
}

run "multiple_network_devices_preserve_order_and_options" {
  command = plan
  variables {
    network_devices = [
      { firewall = true, queues = 4, mtu = 1450, rate_limit = 12.5, vlan_id = 10 },
      { bridge = "vmbr1", model = "e1000", disconnected = true },
    ]
  }
  assert {
    condition = (
      length(proxmox_virtual_environment_vm.this.network_device) == 2 &&
      proxmox_virtual_environment_vm.this.network_device[0].bridge == "vmbr0" &&
      proxmox_virtual_environment_vm.this.network_device[0].model == "virtio" &&
      proxmox_virtual_environment_vm.this.network_device[0].firewall &&
      proxmox_virtual_environment_vm.this.network_device[0].queues == 4 &&
      proxmox_virtual_environment_vm.this.network_device[0].mtu == 1450 &&
      proxmox_virtual_environment_vm.this.network_device[0].rate_limit == 12.5 &&
      proxmox_virtual_environment_vm.this.network_device[0].vlan_id == 10 &&
      proxmox_virtual_environment_vm.this.network_device[1].bridge == "vmbr1" &&
      proxmox_virtual_environment_vm.this.network_device[1].model == "e1000" &&
      proxmox_virtual_environment_vm.this.network_device[1].disconnected
    )
    error_message = "Ordered network devices must preserve their own options and default node bridge."
  }
}

run "display_and_operation_timeouts_are_preserved" {
  command = plan
  variables {
    vga = { type = "virtio", memory = 64 }
    timeouts = {
      create      = 900
      migrate     = 1200
      reboot      = 120
      shutdown_vm = 180
      start_vm    = 240
      stop_vm     = 60
    }
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.vga[0].type == "virtio" &&
      proxmox_virtual_environment_vm.this.vga[0].memory == 64 &&
      proxmox_virtual_environment_vm.this.timeout_create == 900 &&
      proxmox_virtual_environment_vm.this.timeout_migrate == 1200 &&
      proxmox_virtual_environment_vm.this.timeout_reboot == 120 &&
      proxmox_virtual_environment_vm.this.timeout_shutdown_vm == 180 &&
      proxmox_virtual_environment_vm.this.timeout_start_vm == 240 &&
      proxmox_virtual_environment_vm.this.timeout_stop_vm == 60
    )
    error_message = "Display and applicable operation timeouts must be configurable."
  }
}
