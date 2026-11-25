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
