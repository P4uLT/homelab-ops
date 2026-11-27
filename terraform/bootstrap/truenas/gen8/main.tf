resource "truenas_pool" "main" {
  name          = var.pool.name
  force_destroy = false
  topology = {
    data = [{ type = var.pool.layout, disks = var.pool.serials }]
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "truenas_group" "provisioner" {
  name = "terraform-prov"
  smb  = false
}

resource "truenas_user" "provisioner" {
  username             = "terraform-prov"
  full_name            = "OpenTofu provisioning"
  group                = truenas_group.provisioner.id
  group_create         = false
  password_disabled    = true
  ssh_password_enabled = false
  smb                  = false
}

locals {
  # Role names come from the TrueNAS middleware role.py for 25.10, not from the
  # provider docs. The first apply is the check that TrueNAS accepts them.
  # https://github.com/truenas/middleware/blob/TS-25.10.0/src/middlewared/middlewared/role.py
  storage_roles = ["DATASET_READ", "DATASET_WRITE", "SHARING_NFS_READ", "SHARING_NFS_WRITE", "SERVICE_READ"]

  # Each optional capability adds only the roles its operations require.
  share_roles     = var.provision_smb_shares ? ["SHARING_SMB_READ", "SHARING_SMB_WRITE"] : []
  acl_roles       = var.provision_dataset_acls ? ["FILESYSTEM_ATTRS_READ", "FILESYSTEM_ATTRS_WRITE"] : []
  lookup_roles    = var.provision_group_lookup ? ["ACCOUNT_READ"] : []
  app_roles       = var.provision_apps ? ["APPS_READ", "APPS_WRITE", "CATALOG_READ", "CATALOG_WRITE", "DOCKER_READ", "DOCKER_WRITE"] : []
  provision_roles = concat(local.storage_roles, local.share_roles, local.acl_roles, local.lookup_roles, local.app_roles)
}

resource "truenas_privilege" "provisioner" {
  name         = "OpenTofu storage provisioning"
  local_groups = [truenas_group.provisioner.gid]
  roles        = local.provision_roles
  web_shell    = false
}

resource "truenas_api_key" "provisioner" {
  name     = "gen8-provisioning"
  username = truenas_user.provisioner.username

  depends_on = [truenas_privilege.provisioner]
}

resource "truenas_service" "files" {
  for_each = var.services

  name    = each.key
  enabled = each.value
  running = each.value
}
