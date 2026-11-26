mock_provider "truenas" {
  mock_data "truenas_filesystem_acl" {
    defaults = { acltype = "NFS4", path = "/mnt/tank/example" }
  }

  mock_resource "truenas_dataset" {
    defaults = { mountpoint = "/mnt/tank/example" }
  }
}

variables {
  dataset = {
    name       = "tank/example"
    share_type = "sMb"
    filesystem_acl = {
      preset = "nfs4_access"
      groups = { a-readers = "READ", z-publishers = "MODIFY" }
    }
  }
}

run "plans_mixed_group_access" {
  command = plan

  override_data {
    target = data.truenas_group.reader
    values = { gid = 1202 }
  }

  override_data {
    target = data.truenas_group.modifier
    values = { gid = 1201 }
  }

  assert {
    condition = truenas_filesystem_acl.this["managed"].entries == jsonencode([
      { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = { BASIC = "INHERIT" } },
      { tag = "GROUP", id = 1201, type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = { BASIC = "INHERIT" } },
      { tag = "GROUP", id = 1202, type = "ALLOW", perms = { BASIC = "READ" }, flags = { BASIC = "INHERIT" } },
    ])
    error_message = "The ACL must grant the requested inherited rights in numeric GID order."
  }
}

run "rejects_duplicate_resolved_gids" {
  command = plan

  override_data {
    target = data.truenas_group.reader
    values = { gid = 1201 }
  }

  override_data {
    target = data.truenas_group.modifier
    values = { gid = 1201 }
  }

  expect_failures = [truenas_filesystem_acl.this["managed"]]
}

run "rejects_gid_zero" {
  command = plan

  override_data {
    target = data.truenas_group.reader
    values = { gid = 0 }
  }

  override_data {
    target = data.truenas_group.modifier
    values = { gid = 1202 }
  }

  expect_failures = [truenas_filesystem_acl.this["managed"]]
}

run "rejects_empty_grants" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example", share_type = "SMB"
      filesystem_acl = { preset = "nfs4_access" }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_padded_group_names" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example", share_type = "SMB"
      filesystem_acl = { preset = "nfs4_access", groups = { " readers " = "READ" } }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_unknown_rights" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example", share_type = "SMB"
      filesystem_acl = { preset = "nfs4_access", groups = { readers = "FULL_CONTROL" } }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_null_rights" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example", share_type = "SMB"
      filesystem_acl = { preset = "nfs4_access", groups = { readers = null } }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_explicit_posix_with_smb_preset" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example", share_type = "SMB", acltype = "posix"
      filesystem_acl = { preset = "nfs4_access", groups = { readers = "READ" } }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_acl_off_with_smb_preset" {
  command = plan

  variables {
    dataset = {
      name           = "tank/example", share_type = "SMB", acltype = "off"
      filesystem_acl = { preset = "nfs4_access", groups = { readers = "READ" } }
    }
  }

  expect_failures = [var.dataset]
}
