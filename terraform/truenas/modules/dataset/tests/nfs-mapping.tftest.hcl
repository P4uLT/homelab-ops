mock_provider "truenas" {
  mock_data "truenas_service" {
    defaults = { running = true }
  }
}

variables {
  dataset = {
    name = "tank/example"
    nfs  = { hosts = ["client.example.invalid"] }
  }
}

run "looks_up_maproot_user_and_group" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs = {
        hosts         = ["client.example.invalid"]
        maproot_user  = "image-reader"
        maproot_group = "image-readers"
      }
    }
  }

  assert {
    condition = (
      toset(keys(data.truenas_user.nfs_mapping)) == toset(["image-reader"]) &&
      toset(keys(data.truenas_group.nfs_mapping)) == toset(["image-readers"]) &&
      truenas_nfs_share.this[0].maproot_user == "image-reader" &&
      truenas_nfs_share.this[0].maproot_group == "image-readers"
    )
    error_message = "Resolve the configured Maproot identities and pass them to the export."
  }
}

run "looks_up_mapall_user_without_a_group" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs = {
        hosts       = ["client.example.invalid"]
        mapall_user = "backup-writer"
      }
    }
  }

  assert {
    condition = (
      toset(keys(data.truenas_user.nfs_mapping)) == toset(["backup-writer"]) &&
      length(data.truenas_group.nfs_mapping) == 0 &&
      truenas_nfs_share.this[0].mapall_user == "backup-writer"
    )
    error_message = "Resolve only the configured Mapall identity."
  }
}

run "looks_up_mapall_group" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs = {
        hosts        = ["client.example.invalid"]
        mapall_user  = "backup-writer"
        mapall_group = "backup-writers"
      }
    }
  }

  assert {
    condition = (
      toset(keys(data.truenas_group.nfs_mapping)) == toset(["backup-writers"]) &&
      truenas_nfs_share.this[0].mapall_group == "backup-writers"
    )
    error_message = "Resolve the configured Mapall group and pass it to the export."
  }
}

run "rejects_maproot_group_without_user" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs  = { hosts = ["client.example.invalid"], maproot_group = "image-readers" }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_mapall_group_without_user" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs  = { hosts = ["client.example.invalid"], mapall_group = "backup-writers" }
    }
  }

  expect_failures = [var.dataset]
}

run "rejects_empty_user_with_mapping_group" {
  command = plan

  variables {
    dataset = {
      name = "tank/example"
      nfs  = { hosts = ["client.example.invalid"], mapall_group = "backup-writers", mapall_user = "" }
    }
  }

  expect_failures = [var.dataset]
}

run "skips_lookups_for_unmapped_exports" {
  command = plan

  assert {
    condition     = length(data.truenas_user.nfs_mapping) == 0 && length(data.truenas_group.nfs_mapping) == 0
    error_message = "An unmapped export must not need account lookups."
  }
}
