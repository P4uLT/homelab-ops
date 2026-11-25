mock_provider "proxmox" {}

variables {
  state_passphrase = "mock-test-passphrase-only"
  pve_endpoint     = "https://pve.example.invalid:8006/"
  pve_api_token    = "mock@pam!bootstrap=mock"
}

run "fresh_node_has_no_imports" {
  command = plan

  variables {
    adopt_existing_access = false
  }

  assert {
    condition = (
      length(local.access_imports) == 0 &&
      proxmox_virtual_environment_role.terraform_provisioning.role_id == "Terraform_Provisioning" &&
      proxmox_virtual_environment_group.terraform_provisioning.group_id == "Terraform_Provisioning" &&
      proxmox_virtual_environment_user.terraform_prov.user_id == "terraform-prov@pve" &&
      proxmox_acl.terraform_provisioning.path == "/" &&
      proxmox_user_token.tf.token_name == "tf"
    )
    error_message = "A fresh node must plan the access chain without imports."
  }
}
