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
    condition     = length(local.access_imports) == 0
    error_message = "A fresh node must not import access objects."
  }
}
