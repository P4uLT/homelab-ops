mock_provider "proxmox" {}

variables {
  node     = "fixture"
  id       = 1000
  hostname = "fixture"
  template = "NAS:vztmpl/fixture.tar.zst"
  storage  = "local-lvm"
  bridge   = "vmbr0"
}

run "omitted_ipv4_uses_dhcp" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_container.this.initialization[0].ip_config[0].ipv4[0].address == "dhcp"
    error_message = "An omitted IPv4 configuration must use DHCP."
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.initialization[0].ip_config[0].ipv4[0].gateway == null
    error_message = "DHCP must not set a gateway."
  }
}

run "null_ipv4_uses_dhcp" {
  command = plan

  variables {
    ipv4 = null
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.initialization[0].ip_config[0].ipv4[0].address == "dhcp"
    error_message = "A null IPv4 configuration must use DHCP."
  }
}

run "explicit_ipv4_is_preserved" {
  command = plan

  variables {
    # Use a reserved documentation network, not a node address.
    ipv4 = {
      address = format("%d.%d.%d.%d/%d", 192, 0, 2, 10, 24)
      gateway = format("%d.%d.%d.%d", 192, 0, 2, 1)
    }
  }

  assert {
    condition = (
      proxmox_virtual_environment_container.this.initialization[0].ip_config[0].ipv4[0].address == var.ipv4.address &&
      proxmox_virtual_environment_container.this.initialization[0].ip_config[0].ipv4[0].gateway == var.ipv4.gateway
    )
    error_message = "An explicit address and gateway must remain unchanged."
  }
}
