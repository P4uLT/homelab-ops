# Successful input plans target local inventory because datastore outputs can't be mocked.
mock_provider "proxmox" {}

mock_provider "local" {}

variables {
  state_passphrase = "fixture-passphrase-only"
  pve_endpoint     = "https://fixture.invalid:8006/"
  pve_api_token    = "fixture@pve!test=fixture"
  pve_ssh_username = "fixture"
  lxc_workloads    = {}
  vm_image_files   = {}
  vm_image_downloads = {
    fixture = {
      url       = "https://example.invalid/fixture-1.0.qcow2.xz"
      sha256    = "0000000000000000000000000000000000000000000000000000000000000000"
      file_name = "fixture-1.0.qcow2.img"
      storage   = "local-lvm"
    }
  }
}

run "root_preserves_typed_defaults" {
  command = plan
  plan_options {
    target = [local_file.ansible_inventory]
  }
  variables {
    vm_workloads = { fixture = { id = 1001, image = "fixture" } }
  }
  assert {
    condition = (
      var.vm_workloads["fixture"].cpu.cores == 2 &&
      var.vm_workloads["fixture"].cpu.type == "qemu64" &&
      var.vm_workloads["fixture"].memory.dedicated == 4096 &&
      var.vm_workloads["fixture"].memory.floating == 0 &&
      var.vm_workloads["fixture"].disk.interface == "scsi0" &&
      var.vm_workloads["fixture"].agent.enabled &&
      length(var.vm_workloads["fixture"].network_devices) == 1 &&
      var.vm_workloads["fixture"].protection &&
      var.vm_workloads["fixture"].prevent_destroy
    )
    error_message = "The root must preserve the module defaults when workload options are omitted."
  }
}

run "root_accepts_typed_overrides" {
  command = plan
  plan_options {
    target = [local_file.ansible_inventory]
  }
  variables {
    vm_workloads = {
      fixture = {
        id                  = 1001
        image               = "fixture"
        cpu                 = { cores = 4, type = "host", numa = true }
        memory              = { dedicated = 8192, floating = 4096 }
        disk                = { size = 96, interface = "scsi1" }
        agent               = { enabled = false }
        network_devices     = [{ model = "e1000" }, { bridge = "vmbr1" }]
        machine             = "q35"
        reboot_after_update = false
      }
    }
  }
  assert {
    condition = (
      var.vm_workloads["fixture"].cpu.cores == 4 &&
      var.vm_workloads["fixture"].memory.dedicated == 8192 &&
      var.vm_workloads["fixture"].disk.interface == "scsi1" &&
      !var.vm_workloads["fixture"].agent.enabled &&
      length(var.vm_workloads["fixture"].network_devices) == 2 &&
      !var.vm_workloads["fixture"].reboot_after_update
    )
    error_message = "Typed workload overrides must survive root input conversion."
  }
}

run "legacy_ram_cannot_silently_reset_memory" {
  command = plan
  variables {
    vm_workloads = { fixture = { id = 1001, image = "fixture", ram = 8192 } }
  }
  expect_failures = [var.vm_workloads]
}

run "legacy_numa_is_rejected" {
  command = plan
  variables {
    vm_workloads = { fixture = { id = 1001, image = "fixture", numa = true } }
  }
  expect_failures = [var.vm_workloads]
}

run "legacy_network_settings_are_rejected" {
  command = plan
  variables {
    vm_workloads = { fixture = { id = 1001, image = "fixture", vlan_id = 10 } }
  }
  expect_failures = [var.vm_workloads]
}
