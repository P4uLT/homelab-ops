mock_provider "truenas" {
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

run "plans_the_posix_group_preset" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        preset    = "posix_group_rw_others_ro"
        group_gid = 12345
      }
    }
  }

  assert {
    condition = truenas_filesystem_acl.this["managed"].entries == jsonencode(flatten([
      for inherited in [false, true] : [
        for tag in ["USER_OBJ", "GROUP_OBJ", "GROUP", "MASK", "OTHER"] : merge({
          tag     = tag
          default = inherited
          perms   = { READ = true, WRITE = contains(["USER_OBJ", "GROUP", "MASK"], tag), EXECUTE = true }
        }, tag == "GROUP" ? { id = 12345 } : {})
      ]
    ]))
    error_message = "The preset must produce exactly the same ACL as the explicit POSIX rule."
  }

  assert {
    condition     = length(data.truenas_group.acl) == 0
    error_message = "A numeric group ID must not need an account lookup."
  }
}

run "resolves_acl_group_name_to_gid" {
  command = plan

  override_data {
    target = data.truenas_group.acl
    values = { gid = 12345 }
  }

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        preset     = "posix_group_rw_others_ro"
        group_name = "smb-users"
      }
    }
  }

  assert {
    condition = (
      data.truenas_group.acl["managed"].name == "smb-users" &&
      jsondecode(truenas_filesystem_acl.this["managed"].entries)[2].id == 12345 &&
      jsondecode(truenas_filesystem_acl.this["managed"].entries)[7].id == 12345 &&
      !can(jsondecode(truenas_filesystem_acl.this["managed"].entries)[2].who)
    )
    error_message = "Resolve the group by name but send its numeric GID in both ACEs."
  }
}

run "looks_up_each_group_in_a_preset" {
  command = plan

  override_data {
    target = data.truenas_group.acl
    values = { gid = 12345 }
  }

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        preset      = "posix_group_rw_others_ro"
        group_names = ["smb-users", "iso-editors"]
      }
    }
  }

  assert {
    condition = (
      toset(keys(data.truenas_group.acl)) == toset(["smb-users", "iso-editors"]) &&
      data.truenas_group.acl["smb-users"].name == "smb-users" &&
      data.truenas_group.acl["iso-editors"].name == "iso-editors" &&
      [for ace in jsondecode(truenas_filesystem_acl.this["managed"].entries) : ace.id if ace.tag == "GROUP"] == [12345, 12345]
    )
    error_message = "Resolve each group by name and emit one access and one inherited entry per distinct GID."
  }
}

run "rejects_mixing_singular_and_plural_group_names" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        preset      = "posix_group_rw_others_ro"
        group_name  = "smb-users"
        group_names = ["iso-editors"]
      }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_both_group_name_and_gid" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      filesystem_acl = {
        preset     = "posix_group_rw_others_ro"
        group_name = "smb-users"
        group_gid  = 12345
      }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_an_unknown_acl_preset" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example"
      filesystem_acl = { preset = "unknown", group_gid = 12345 }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_mixing_a_preset_with_custom_acl_settings" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example"
      filesystem_acl = { preset = "posix_group_rw_others_ro", group_gid = 12345, type = "POSIX1E" }
    }
  }

  expect_failures = [var.dataset]
}

run "retains_the_disabled_share_address" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs  = { hosts = ["pve.example.invalid"], ro = true, enabled = false }
    }
  }

  assert {
    condition     = length(truenas_nfs_share.this) == 1 && !truenas_nfs_share.this["share"].enabled
    error_message = "A disabled export must retain its resource address."
  }
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
