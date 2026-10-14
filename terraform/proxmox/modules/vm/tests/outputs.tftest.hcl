mock_provider "proxmox" {}
override_resource {
  target = proxmox_virtual_environment_vm.this
  values = {
    ipv4_addresses = [["fixture-address-not-a-node"]]
  }
}
variables {
  node          = "fixture"
  storage       = "local-lvm"
  bridge        = "vmbr0"
  id            = 1001
  name          = "fixture-haos"
  image_file_id = "local:iso/haos_ova-18.3.qcow2.img"
}
run "network_outputs_are_sensitive_and_preserve_values" {
  command = plan
  assert {
    condition     = issensitive(output.ipv4_addresses)
    error_message = "VM network outputs must be sensitive."
  }
  assert {
    condition = (
      length(nonsensitive(output.ipv4_addresses)) == 1 &&
      nonsensitive(output.ipv4_addresses)[0][0] == "fixture-address-not-a-node"
    )
    error_message = "Sensitivity must preserve the reported address values."
  }
  assert {
    condition     = !issensitive(output.vm_id) && output.vm_id == 1001
    error_message = "The standalone VM ID must remain public."
  }
}
