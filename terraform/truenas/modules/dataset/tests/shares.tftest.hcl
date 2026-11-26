mock_provider "truenas" {
  mock_data "truenas_service" {
    defaults = { running = true, enabled = true }
  }

  mock_resource "truenas_dataset" {
    defaults = { mountpoint = "/mnt/tank/example" }
  }
}

variables {
  dataset = {
    name = "tank/example"
    nfs  = { hosts = ["pve.example.invalid"], ro = true }
  }
}

run "creates_nfs_share_on_the_dataset_mountpoint" {
  command = plan

  assert {
    condition     = truenas_nfs_share.this["share"].path == truenas_dataset.this.mountpoint
    error_message = "The share must use the mountpoint returned by TrueNAS."
  }
}

run "plans_an_opt_in_acl" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        type = "POSIX1E"
        entries = [
          { tag = "GROUP", who = "smb-users", default = false, perms = { READ = true, WRITE = true, EXECUTE = true } },
          { tag = "MASK", default = false, perms = { READ = true, WRITE = true, EXECUTE = true } },
        ]
      }
    }
  }

  assert {
    condition = jsondecode(truenas_filesystem_acl.this["managed"].entries)[0] == {
      tag     = "GROUP"
      who     = "smb-users"
      default = false
      perms   = { READ = true, WRITE = true, EXECUTE = true }
    }
    error_message = "The provider payload must preserve the group name and omit unused fields."
  }
}

run "mirrors_posix_access_entries_for_inheritance" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        type           = "POSIX1E"
        inherit_access = true
        entries = [
          { tag = "USER_OBJ", perms = { READ = true, WRITE = true, EXECUTE = true } },
          { tag = "GROUP_OBJ", perms = { READ = true, WRITE = false, EXECUTE = true } },
          { tag = "GROUP", id = 12345, perms = { READ = true, WRITE = true, EXECUTE = true } },
          { tag = "MASK", perms = { READ = true, WRITE = true, EXECUTE = true } },
          { tag = "OTHER", perms = { READ = true, WRITE = false, EXECUTE = true } },
        ]
      }
    }
  }

  assert {
    condition = truenas_filesystem_acl.this["managed"].entries == jsonencode(flatten([
      for inherited in [false, true] : [
        for ace in var.dataset.filesystem_acl.entries :
        merge(ace, { default = inherited })
      ]
    ]))
    error_message = "The shortcut must produce the same ordered ACL as the explicit entries."
  }
}

run "allows_an_acl_conversion_in_the_same_apply" {
  command = plan

  override_data {
    target = data.truenas_filesystem_acl.this
    values = { acltype = "POSIX1E" }
  }

  override_data {
    target = data.truenas_group.modifier
    values = { gid = 12345 }
  }

  variables {
    dataset = {
      name       = "tank/example"
      acltype    = "nfsv4"
      share_type = "MULTIPROTOCOL"
      filesystem_acl = {
        preset = "nfs4_access"
        groups = { smb-users = "MODIFY" }
      }
    }
  }

  assert {
    condition     = truenas_dataset.this.acltype == "nfsv4"
    error_message = "A dataset declared with nfsv4 must accept the NFS4 ACL in the same apply."
  }
}

run "rejects_the_nfs4_preset_on_a_posix_dataset" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example"
      share_type     = "GENERIC"
      filesystem_acl = { preset = "nfs4_access", groups = { smb-users = "MODIFY" } }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_an_unknown_acl_preset" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example"
      filesystem_acl = { preset = "unknown", groups = { smb-users = "MODIFY" } }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_mixing_a_preset_with_custom_acl_settings" {
  command = plan

  variables {
    dataset = {
      name       = "tank/example"
      share_type = "SMB"
      filesystem_acl = {
        preset  = "nfs4_access"
        groups  = { smb-users = "MODIFY" }
        entries = [{ tag = "owner@", type = "ALLOW", basic_perms = "FULL_CONTROL" }]
      }
    }
  }

  expect_failures = [var.dataset]
}

run "resolves_nfs4_group_and_user_names" {
  command = plan

  override_data {
    target = data.truenas_group.entry
    values = { gid = 12345 }
  }

  override_data {
    target = data.truenas_user.entry
    values = { uid = 0 }
  }

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        type = "NFS4"
        entries = [
          { tag = "GROUP", type = "ALLOW", group = "smb-users", basic_perms = "MODIFY", basic_flags = "INHERIT" },
          { tag = "USER", type = "ALLOW", user = "root", basic_perms = "MODIFY", basic_flags = "INHERIT" },
        ]
      }
    }
  }

  assert {
    condition = [
      for ace in jsondecode(truenas_filesystem_acl.this["managed"].entries) : ace.id
    ] == [12345, 0]
    error_message = "Send numeric IDs, not names, for group and user entries."
  }

  assert {
    condition     = alltrue([for ace in jsondecode(truenas_filesystem_acl.this["managed"].entries) : !can(ace.who)])
    error_message = "Never store a name in who, which needs a lookup on every refresh."
  }
}

run "allows_a_reviewed_replacement" {
  command = plan

  override_data {
    target = data.truenas_group.modifier
    values = { gid = 12345 }
  }

  variables {
    dataset = {
      name       = "tank/replacement"
      protect    = false
      share_type = "MULTIPROTOCOL"
      filesystem_acl = {
        preset = "nfs4_access"
        groups = { smb-users = "MODIFY" }
      }
    }
  }

  assert {
    condition = (
      truenas_dataset.this.name == "tank/replacement" &&
      !truenas_dataset.this.force_destroy &&
      length(truenas_filesystem_acl.this) == 1
    )
    error_message = "A reviewed replacement must rebuild the dataset and its ACL without force-destroy."
  }
}

run "keeps_guest_access_closed_on_a_legacy_share" {
  command = plan

  variables {
    dataset = { name = "tank/example", smb = { name = "example", purpose = "LEGACY_SHARE" } }
  }

  assert {
    condition     = truenas_smb_share.this["share"].guestok == false
    error_message = "An omitted guestok must stay closed on a legacy share."
  }
}

run "passes_the_recursive_choice_to_the_provider" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        type      = "NFS4"
        recursive = true
        entries   = [{ tag = "owner@", type = "ALLOW", basic_perms = "FULL_CONTROL", basic_flags = "INHERIT" }]
      }
    }
  }

  assert {
    condition     = var.dataset.filesystem_acl.recursive && length(truenas_filesystem_acl.this) == 1
    error_message = "A recursive ACL update must reach the ACL resource."
  }
}

run "rejects_a_posix_acl_on_an_smb_dataset" {
  command = plan

  variables {
    dataset = {
      name       = "tank/example"
      share_type = "SMB"
      filesystem_acl = {
        type    = "POSIX1E"
        entries = [{ tag = "USER_OBJ", perms = { READ = true, WRITE = true, EXECUTE = true } }]
      }
    }
  }

  expect_failures = [var.dataset]
}

run "maps_dataset_acl_types_to_entry_types" {
  command = plan

  variables {
    dataset = { name = "tank/example", acltype = "nfsv4", share_type = "MULTIPROTOCOL" }
  }

  assert {
    condition = (
      local.acl_type_from_dataset["nfsv4"] == "NFS4" &&
      local.acl_type_from_dataset["posix"] == "POSIX1E"
    )
    error_message = "The dataset vocabulary and the entry vocabulary must map explicitly."
  }
}

run "rejects_an_invalid_type_on_a_named_entry" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        type = "NFS4"
        entries = [
          { tag = "GROUP", group = "smb-users", type = "BOGUS", perms = { READ = true } },
        ]
      }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_two_permission_forms_on_a_named_entry" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        type = "NFS4"
        entries = [
          { tag = "GROUP", group = "smb-users", type = "ALLOW", perms = { READ = true }, basic_perms = "MODIFY" },
        ]
      }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_two_identities_on_one_entry" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        type = "NFS4"
        entries = [
          { tag = "GROUP", group = "smb-users", id = 12345, type = "ALLOW", basic_perms = "MODIFY" },
        ]
      }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_a_nested_dataset_path" {
  command = plan

  variables {
    dataset = { name = "tank/a/b" }
  }

  expect_failures = [var.dataset]
}

run "rejects_an_unknown_dataset_preset" {
  command = plan

  variables {
    dataset = { name = "tank/example", share_type = "SMB2" }
  }

  expect_failures = [var.dataset]
}

run "rejects_an_unknown_acl_type" {
  command = plan

  variables {
    dataset = { name = "tank/example", acltype = "windows" }
  }

  expect_failures = [var.dataset]
}

run "rejects_an_unknown_smb_purpose" {
  command = plan

  variables {
    dataset = { name = "tank/example", smb = { name = "example", purpose = "SHARE" } }
  }

  expect_failures = [var.dataset]
}

run "retains_disabled_shares_when_services_are_stopped" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs  = { hosts = ["pve.example.invalid"], ro = true, enabled = false }
      smb  = { name = "example", enabled = false }
    }
  }

  override_data {
    target = data.truenas_service.files
    values = { running = false }
  }

  assert {
    condition     = !truenas_nfs_share.this["share"].enabled && !truenas_smb_share.this["share"].enabled
    error_message = "Disabled shares must retain their resource addresses."
  }
}

run "rejects_enabled_nfs_when_service_is_stopped" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs  = { hosts = ["pve.example.invalid"], enabled = true }
    }
  }

  override_data {
    target = data.truenas_service.files
    values = { running = false }
  }

  expect_failures = [truenas_nfs_share.this["share"]]
}

run "rejects_enabled_smb_when_service_is_stopped" {
  command = plan

  variables {
    dataset = { name = "tank/example", smb = { name = "example" } }
  }

  override_data {
    target = data.truenas_service.files
    values = { running = false }
  }

  expect_failures = [truenas_smb_share.this["share"]]
}

run "rejects_conflicting_nfs_mappings" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs  = { hosts = ["pve.example.invalid"], maproot_user = "root", mapall_user = "nobody" }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_world_access" {
  command = plan

  variables {
    dataset = { name = "tank/example", nfs = { networks = ["0.0.0.0/0"] } }
  }

  expect_failures = [var.dataset]
}
