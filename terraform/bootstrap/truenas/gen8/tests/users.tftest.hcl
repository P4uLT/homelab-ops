mock_provider "truenas" {
  mock_resource "truenas_group" {
    defaults = { id = 1234 }
  }
}

variables {
  truenas_host           = "nas.example.invalid"
  truenas_api_key        = "mock-only"
  state_passphrase       = "mock-only-passphrase"
  disk_serials           = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"]
  provision_smb_shares   = true
  provision_dataset_acls = false
  provision_group_lookup = false
  groups = {
    iso = { name = "iso-writers", smb = true }
  }
  users = {
    windows = {
      username      = "iso-writer"
      full_name     = "ISO publisher"
      primary_group = "iso"
      smb           = true
    }
  }
  user_passwords = { windows = "mock-only-password" }
}

run "plans_a_separate_file_identity" {
  command = plan

  assert {
    condition = (
      truenas_user.managed["windows"].username == "iso-writer" &&
      truenas_user.managed["windows"].smb &&
      truenas_group.managed["iso"].name == "iso-writers" &&
      !truenas_user.provisioner.smb &&
      !contains(truenas_privilege.provisioner.roles, "ACCOUNT_WRITE") &&
      !contains(truenas_privilege.provisioner.roles, "ACCOUNT_READ") &&
      !contains(truenas_privilege.provisioner.roles, "FILESYSTEM_ATTRS_WRITE")
    )
    error_message = "The Windows account must be separate from the provisioning identity."
  }
}

run "opts_in_to_acl_permissions_without_account_permissions" {
  command = plan

  variables {
    provision_dataset_acls = true
  }

  assert {
    condition = alltrue([
      contains(truenas_privilege.provisioner.roles, "FILESYSTEM_ATTRS_READ"),
      contains(truenas_privilege.provisioner.roles, "FILESYSTEM_ATTRS_WRITE"),
      !contains(truenas_privilege.provisioner.roles, "ACCOUNT_WRITE"),
    ])
    error_message = "Managing dataset ACLs must not grant account management."
  }
}

run "opts_in_to_group_lookup_without_account_write" {
  command = plan

  variables {
    provision_group_lookup = true
  }

  assert {
    condition = (
      contains(truenas_privilege.provisioner.roles, "ACCOUNT_READ") &&
      !contains(truenas_privilege.provisioner.roles, "ACCOUNT_WRITE")
    )
    error_message = "Group lookup must grant account read access only."
  }
}

run "rejects_unknown_group" {
  command = plan

  variables {
    users = {
      windows = { username = "iso-writer", full_name = "ISO publisher", primary_group = "missing" }
    }
  }

  expect_failures = [var.users]
}

run "rejects_smb_user_without_password" {
  command = plan

  variables {
    user_passwords = {}
  }

  expect_failures = [var.user_passwords]
}
