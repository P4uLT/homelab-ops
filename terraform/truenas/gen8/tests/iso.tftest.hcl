mock_provider "truenas" {
  mock_data "truenas_user" {
    defaults = { uid = 1201 }
  }

  mock_data "truenas_filesystem_acl" {
    defaults = { acltype = "NFS4", path = "/mnt/tank/iso" }
  }

  mock_resource "truenas_dataset" {
    defaults = { mountpoint = "/mnt/tank/iso" }
  }

  mock_data "truenas_service" {
    defaults = { running = true, enabled = true }
  }
}

variables {
  truenas_host     = "nas.example.invalid"
  truenas_api_key  = "mock-only"
  state_passphrase = "mock-only-passphrase"
  datasets = {
    iso = {
      name       = "tank/iso"
      recordsize = "1M"
      nfs = {
        hosts = ["pve.example.invalid"]
        ro    = true
      }
      smb = { name = "iso", ro = true, guestok = false }
    }
    arrdata = {
      name = "tank/arrdata"
      nfs  = { networks = ["192.0.2.0/24"], enabled = false }
    }
    rustfs = { name = "tank/rustfs" }
    perso  = { name = "tank/perso", smb = { name = "Personal" } }
  }
}

run "plans_independent_datasets_and_optional_exports" {
  command = plan

  assert {
    condition = (
      module.dataset["iso"].name == "tank/iso" &&
      module.dataset["iso"].nfs.ro &&
      module.dataset["iso"].smb.name == "iso" &&
      toset(module.dataset["iso"].nfs.hosts) == toset(["pve.example.invalid"]) &&
      !module.dataset["arrdata"].nfs.enabled &&
      !module.dataset["arrdata"].nfs.ro &&
      module.dataset["rustfs"].nfs == null &&
      module.dataset["rustfs"].smb == null &&
      module.dataset["perso"].smb.name == "Personal"
    )
    error_message = "Each dataset must get only its requested exports and settings."
  }
}

run "plans_iso_with_acl_users" {
  command = plan

  variables {
    datasets = {
      iso = {
        name       = "tank/iso"
        share_type = "MULTIPROTOCOL"
        filesystem_acl = {
          preset = "nfs4_access"
          users  = { iso-reader = "READ" }
        }
        nfs = { hosts = ["pve.example.invalid"], ro = true }
        smb = { name = "iso", purpose = "MULTIPROTOCOL_SHARE" }
      }
    }
  }

  assert {
    condition     = module.dataset["iso"].nfs.ro && module.dataset["iso"].smb.enabled
    error_message = "The catalog must pass the ACL grants to a dataset with both shares."
  }
}

run "rejects_unrestricted_nfs" {
  command = plan

  variables {
    datasets = { iso = { name = "tank/iso", nfs = {} } }
  }

  expect_failures = [var.datasets]
}

run "rejects_duplicate_dataset_names" {
  command = plan

  variables {
    datasets = { first = { name = "tank/iso" }, second = { name = "tank/iso" } }
  }

  expect_failures = [var.datasets]
}
