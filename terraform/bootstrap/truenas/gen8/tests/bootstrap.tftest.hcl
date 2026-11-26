mock_provider "truenas" {
  mock_resource "truenas_api_key" {
    defaults = { key = "mock-provisioner-key" }
  }
}

variables {
  truenas_host         = "nas.example.invalid"
  truenas_api_key      = "mock-only"
  state_passphrase     = "mock-only-passphrase"
  pool                 = { serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"] }
  services             = { nfs = true, cifs = true }
  provision_smb_shares = false
}

run "plans_a_single_raidz2_vdev_by_default" {
  command = plan

  assert {
    condition = (
      truenas_pool.main.name == "tank" &&
      length(truenas_pool.main.topology.data) == 1 &&
      truenas_pool.main.topology.data[0].type == "RAIDZ2" &&
      length(truenas_pool.main.topology.data[0].disks) == 4 &&
      !truenas_pool.main.force_destroy &&
      truenas_user.provisioner.password_disabled &&
      !truenas_user.provisioner.smb &&
      !contains(truenas_privilege.provisioner.roles, "SHARING_SMB_WRITE") &&
      truenas_service.files["nfs"].running &&
      truenas_service.files["cifs"].running
    )
    error_message = "Expected a protected default pool, a limited API identity, and both file services."
  }
}

run "plans_a_mirror_vdev" {
  command = plan

  variables {
    pool = { name = "tank", layout = "MIRROR", serials = ["DRIVE-A", "DRIVE-B"] }
  }

  assert {
    condition = (
      truenas_pool.main.topology.data[0].type == "MIRROR" &&
      length(truenas_pool.main.topology.data[0].disks) == 2
    )
    error_message = "A MIRROR layout must pass its two serials as one vdev."
  }
}

run "plans_a_raidz_vdev" {
  command = plan

  variables {
    pool = { name = "tank", layout = "RAIDZ", serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C"] }
  }

  assert {
    condition = (
      truenas_pool.main.topology.data[0].type == "RAIDZ" &&
      length(truenas_pool.main.topology.data[0].disks) == 3
    )
    error_message = "A RAIDZ layout must pass its three serials as one vdev."
  }
}

run "rejects_an_unknown_layout" {
  command = plan

  variables {
    pool = { name = "tank", layout = "STRIPE", serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"] }
  }

  expect_failures = [var.pool]
}

run "rejects_too_few_disks_for_raidz2" {
  command = plan

  variables {
    pool = { name = "tank", layout = "RAIDZ2", serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C"] }
  }

  expect_failures = [var.pool]
}

run "rejects_duplicate_serials" {
  command = plan

  variables {
    pool = {
      name    = "tank"
      layout  = "RAIDZ2"
      serials = ["DRIVE-A", "drive-a", "DRIVE-C", "DRIVE-D"]
    }
  }

  expect_failures = [var.pool]
}

run "rejects_an_invalid_pool_name" {
  command = plan

  variables {
    pool = { name = "0tank", layout = "RAIDZ2", serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"] }
  }

  expect_failures = [var.pool]
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
