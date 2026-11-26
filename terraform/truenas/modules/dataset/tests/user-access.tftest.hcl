mock_provider "truenas" {
  mock_data "truenas_filesystem_acl" {
    defaults = { acltype = "NFS4", path = "/mnt/tank/example" }
  }

  mock_data "truenas_user" {
    defaults = { uid = 1201 }
  }

  mock_data "truenas_group" {
    defaults = { gid = 1201 }
  }

  mock_resource "truenas_dataset" {
    defaults = { mountpoint = "/mnt/tank/example" }
  }
}

variables {
  dataset = {
    name       = "tank/example"
    share_type = "SMB"
    filesystem_acl = {
      preset = "nfs4_access"
      users  = { backup = "MODIFY" }
    }
  }
}

run "grants_access_to_one_user_without_a_group" {
  command = plan

  assert {
    condition = truenas_filesystem_acl.this["managed"].entries == jsonencode([
      { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = { BASIC = "INHERIT" } },
      { tag = "USER", id = 1201, type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = { BASIC = "INHERIT" } },
    ])
    error_message = "A user-only preset must grant inherited access without a group entry."
  }
}

run "keeps_user_and_group_with_the_same_numeric_id_distinct" {
  command = plan

  variables {
    dataset = {
      name       = "tank/example"
      share_type = "SMB"
      filesystem_acl = {
        preset = "nfs4_access"
        groups = { publishers = "MODIFY" }
        users  = { reader = "READ" }
      }
    }
  }

  assert {
    condition = truenas_filesystem_acl.this["managed"].entries == jsonencode([
      { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = { BASIC = "INHERIT" } },
      { tag = "GROUP", id = 1201, type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = { BASIC = "INHERIT" } },
      { tag = "USER", id = 1201, type = "ALLOW", perms = { BASIC = "READ" }, flags = { BASIC = "INHERIT" } },
    ])
    error_message = "UNIX user and group IDs are separate namespaces."
  }
}

run "refuses_a_user_resolved_to_root" {
  command = plan

  override_data {
    target = data.truenas_user.preset
    values = { uid = 0 }
  }

  expect_failures = [truenas_filesystem_acl.this["managed"]]
}

run "rejects_duplicate_resolved_user_ids" {
  command = plan

  variables {
    dataset = {
      name       = "tank/example"
      share_type = "SMB"
      filesystem_acl = {
        preset = "nfs4_access"
        users  = { reader = "READ", writer = "MODIFY" }
      }
    }
  }

  expect_failures = [truenas_filesystem_acl.this["managed"]]
}
