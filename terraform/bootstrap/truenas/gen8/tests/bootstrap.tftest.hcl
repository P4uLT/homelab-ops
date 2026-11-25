mock_provider "truenas" {
  mock_resource "truenas_api_key" {
    defaults = { key = "mock-provisioner-key" }
  }
}

variables {
  truenas_host         = "nas.example.invalid"
  truenas_api_key      = "mock-only"
  state_passphrase     = "mock-only-passphrase"
  disk_serials         = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"]
  services             = { nfs = true, cifs = true }
  provision_smb_shares = false
}

run "selects_one_four_disk_raidz2_vdev" {
  command = plan

  assert {
    condition = (
      length(truenas_pool.tank.topology.data) == 1 &&
      truenas_pool.tank.topology.data[0].type == "RAIDZ2" &&
      length(truenas_pool.tank.topology.data[0].disks) == 4 &&
      !truenas_pool.tank.force_destroy &&
      truenas_user.provisioner.password_disabled &&
      !truenas_user.provisioner.smb &&
      !contains(truenas_privilege.provisioner.roles, "SHARING_SMB_WRITE") &&
      truenas_service.files["nfs"].running &&
      truenas_service.files["cifs"].running
    )
    error_message = "Expected protected RAIDZ2 storage, a limited API identity, and both file services."
  }
}

run "issues_a_key_for_the_provisioner" {
  command = plan

  assert {
    condition     = truenas_api_key.provisioner.username == truenas_user.provisioner.username
    error_message = "The generated API key must belong to the provisioning account."
  }

  assert {
    condition     = output.api_key_value == truenas_api_key.provisioner.key
    error_message = "The output must return the generated provisioning key."
  }
}

run "rejects_duplicate_serials" {
  command = plan

  variables {
    disk_serials = ["DRIVE-A", "drive-a", "DRIVE-C", "DRIVE-D"]
  }

  expect_failures = [var.disk_serials]
}

run "switches_cifs_off_without_removing_its_resource" {
  command = plan

  variables {
    services = { nfs = true, cifs = false }
  }

  assert {
    condition     = !truenas_service.files["cifs"].running && !truenas_service.files["cifs"].enabled
    error_message = "An off service must remain managed but stopped and disabled."
  }
}
