mock_provider "truenas" {
  mock_resource "truenas_api_key" {
    defaults = { key = "mock-provisioner-key" }
  }
}

variables {
  acme_enabled         = false
  acme_assign_admin    = false
  truenas_host         = "nas.example.invalid"
  truenas_api_key      = "mock-only"
  state_passphrase     = "mock-only-passphrase"
  pool                 = { serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"] }
  services             = { nfs = true, cifs = true }
  provision_smb_shares = false
  provision_apps       = true
}

run "provisioner_gains_apps_roles_when_gated" {
  command = plan

  assert {
    condition = alltrue([
      for role in ["APPS_READ", "APPS_WRITE", "CATALOG_READ", "CATALOG_WRITE", "DOCKER_READ", "DOCKER_WRITE"] :
      contains(truenas_privilege.provisioner.roles, role)
    ])
    error_message = "provision_apps must grant the six apps-subsystem roles."
  }
}
