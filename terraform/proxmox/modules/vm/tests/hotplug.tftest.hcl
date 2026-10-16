mock_provider "proxmox" {}

variables {
  node          = "fixture"
  storage       = "local-lvm"
  bridge        = "vmbr0"
  id            = 1001
  name          = "fixture-hotplug"
  image_file_id = "local:iso/haos_ova-18.3.qcow2.img"
}

run "default_hotplug_preserves_pve_features" {
  command = plan
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.hotplug == "disk,network,usb" &&
      !proxmox_virtual_environment_vm.this.cpu[0].numa
    )
    error_message = "Default hotplug must enable disk, network, and USB without NUMA."
  }
}

run "null_inputs_keep_hotplug_defaults" {
  command = plan
  variables {
    hotplug = null
    cpu     = null
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.hotplug == "disk,network,usb" &&
      !proxmox_virtual_environment_vm.this.cpu[0].numa
    )
    error_message = "Null hotplug and NUMA inputs must retain the defaults."
  }
}

run "empty_features_disable_hotplug" {
  command = plan
  variables { hotplug = [] }
  assert {
    condition     = proxmox_virtual_environment_vm.this.hotplug == "0"
    error_message = "An empty feature set must disable hotplug."
  }
}

run "all_features_are_supported_with_numa" {
  command = plan
  variables {
    hotplug = ["usb", "memory", "network", "disk", "cpu"]
    cpu     = { numa = true }
  }
  assert {
    condition = (
      proxmox_virtual_environment_vm.this.hotplug == "cpu,disk,memory,network,usb" &&
      proxmox_virtual_environment_vm.this.cpu[0].numa
    )
    error_message = "Explicit features must map to a stable provider value with NUMA enabled."
  }
}

run "unknown_features_are_rejected" {
  command = plan
  variables { hotplug = ["disks"] }
  expect_failures = [var.hotplug]
}

run "provider_sentinels_are_not_feature_names" {
  command = plan
  variables { hotplug = ["0"] }
  expect_failures = [var.hotplug]
}

run "memory_hotplug_requires_numa" {
  command = plan
  variables { hotplug = ["memory"] }
  expect_failures = [var.hotplug]
}
