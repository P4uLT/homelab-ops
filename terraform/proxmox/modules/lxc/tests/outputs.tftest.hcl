mock_provider "proxmox" {
  mock_resource "proxmox_virtual_environment_container" {
    defaults = {
      ipv4 = { eth0 = "fixture-address-not-a-node" }
    }
  }
}

variables {
  node     = "fixture"
  id       = 1000
  hostname = "fixture"
  template = "NAS:vztmpl/fixture.tar.zst"
  storage  = "local-lvm"
  bridge   = "vmbr0"
}

run "network_output_is_sensitive" {
  command = plan

  assert {
    condition     = issensitive(output.ct_ipv4)
    error_message = "The network output must be marked sensitive."
  }

  assert {
    condition     = nonsensitive(output.ct_ipv4) == "fixture-address-not-a-node"
    error_message = "Sensitivity must not change the network output value."
  }

  assert {
    condition     = !issensitive(output.ct_id)
    error_message = "The container ID must remain a public output."
  }
}
