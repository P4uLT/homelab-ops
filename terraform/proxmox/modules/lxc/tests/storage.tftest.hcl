mock_provider "proxmox" {}

variables {
  node     = "fixture"
  id       = 1000
  hostname = "fixture"
  template = "NAS:vztmpl/fixture.tar.zst"
  storage  = "local-lvm"
  bridge   = "vmbr0"
}

run "unitless_mount_size_is_rejected" {
  command = plan

  variables {
    mountpoints = [{
      volume = "local-lvm"
      path   = "/srv/data"
      size   = 10
    }]
  }

  expect_failures = [var.mountpoints]
}

run "gibibyte_mount_size_is_preserved" {
  command = plan

  variables {
    mountpoints = [{
      volume = "local-lvm"
      path   = "/srv/data"
      size   = "10G"
      backup = true
    }]
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.mount_point[0].size == "10G"
    error_message = "The provider must receive the requested size with its unit."
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.mount_point[0].backup == true
    error_message = "The mount point backup flag must remain enabled."
  }
}

run "mebibyte_mount_size_is_preserved" {
  command = plan

  variables {
    mountpoints = [{
      volume = "local-lvm"
      path   = "/srv/data"
      size   = "512M"
    }]
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.mount_point[0].size == "512M"
    error_message = "The size must retain its requested unit."
  }
}

run "an_existing_volume_can_omit_size" {
  command = plan

  variables {
    mountpoints = [{
      volume = "local-lvm:vm-1000-disk-1"
      path   = "/srv/data"
    }]
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.mount_point[0].size == null
    error_message = "An existing volume must not acquire an implicit size."
  }
}
