mock_provider "truenas" {}

variables {
  acme_admin_certificate_name = null
  truenas_host                = "nas.example.net"
  truenas_api_key             = "mock-only"
  state_passphrase            = "mock-only-passphrase"
  pool                        = { serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"] }
  groups                      = {}
  users                       = {}
  user_passwords              = {}

  acme_enabled = true
  acme         = { ovh_endpoint = "ovh-eu", accept_terms = true }
  acme_certificates = [
    { name = "admin", common_name = "nas.example.net" },
    { name = "apps", common_name = "*.apps.example.net" },
  ]
  acme_ovh_credentials = {
    application_key    = "mock-application-key"
    application_secret = "mock-application-secret"
    consumer_key       = "mock-consumer-key"
  }
}

run "rejects_missing_acme_settings" {
  command = plan

  variables {
    acme = null
  }

  expect_failures = [var.acme]
}

run "rejects_unaccepted_terms" {
  command = plan

  variables {
    acme = { ovh_endpoint = "ovh-eu", accept_terms = false }
  }

  expect_failures = [var.acme]
}

run "rejects_an_unsupported_ovh_endpoint" {
  command = plan

  variables {
    acme = { ovh_endpoint = "unsupported", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_enabled_issuance_without_certificates" {
  command = plan

  variables {
    acme_certificates = []
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_duplicate_certificate_names" {
  command = plan

  variables {
    acme_certificates = [
      { name = "admin", common_name = "nas.example.net" },
      { name = "admin", common_name = "other.example.net" },
    ]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_an_invalid_object_name" {
  command = plan

  variables {
    acme_certificates = [{ name = "admin.invalid", common_name = "nas.example.net" }]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_a_hostname_with_a_scheme_and_port" {
  command = plan

  variables {
    acme_certificates = [{ name = "admin", common_name = "https://nas.example.net:443" }]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_a_hostname_with_an_empty_label" {
  command = plan

  variables {
    acme_certificates = [{ name = "admin", common_name = "nas..example.net" }]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_an_address_as_a_dns_name" {
  command = plan

  variables {
    acme_certificates = [{ name = "admin", common_name = "192.0.2.10" }]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_a_wildcard_outside_the_first_label" {
  command = plan

  variables {
    acme_certificates = [{ name = "admin", common_name = "nas.example.net", san = ["apps.*.example.net"] }]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_a_san_with_a_trailing_dot" {
  command = plan

  variables {
    acme_certificates = [{ name = "admin", common_name = "nas.example.net", san = ["apps.example.net."] }]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_a_null_entry" {
  command = plan

  variables {
    acme_certificates = [null]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_a_null_san" {
  command = plan

  variables {
    acme_certificates = [{ name = "admin", common_name = "nas.example.net", san = [null] }]
  }

  expect_failures = [var.acme_certificates]
}

run "rejects_missing_ovh_credentials" {
  command = plan

  variables {
    acme_ovh_credentials = null
  }

  expect_failures = [var.acme_ovh_credentials]
}

run "rejects_blank_ovh_credentials" {
  command = plan

  variables {
    acme_ovh_credentials = { application_key = "mock-key", application_secret = "  ", consumer_key = "mock-consumer" }
  }

  expect_failures = [var.acme_ovh_credentials]
}

run "rejects_a_nonpositive_credential_version" {
  command = plan

  variables {
    acme_ovh_credentials_version = 0
  }

  expect_failures = [var.acme_ovh_credentials_version]
}

run "rejects_a_fractional_credential_version" {
  command = plan

  variables {
    acme_ovh_credentials_version = 1.5
  }

  expect_failures = [var.acme_ovh_credentials_version]
}

run "rejects_binding_the_admin_certificate_without_issuance" {
  command = plan

  variables {
    acme_enabled                = false
    acme_admin_certificate_name = "admin"
  }

  expect_failures = [var.acme_admin_certificate_name]
}

run "rejects_binding_an_unknown_certificate" {
  command = plan

  variables {
    acme_admin_certificate_name = "missing"
  }

  expect_failures = [var.acme_admin_certificate_name]
}

run "rejects_binding_when_the_provider_uses_another_hostname" {
  command = plan

  variables {
    truenas_host                = "old-nas.example.net"
    acme_admin_certificate_name = "admin"
  }

  expect_failures = [var.acme_admin_certificate_name]
}

run "rejects_a_prefix_with_a_dns_separator" {
  command = plan

  variables {
    acme = { name_prefix = "storage.lab", ovh_endpoint = "ovh-eu", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_a_fractional_authenticator_id" {
  command = plan

  variables {
    acme                 = { dns_authenticator_id = 1.5, accept_terms = true }
    acme_ovh_credentials = null
  }

  expect_failures = [var.acme]
}

run "rejects_combining_an_existing_id_with_an_ovh_endpoint" {
  command = plan

  variables {
    acme                 = { dns_authenticator_id = 913, ovh_endpoint = "ovh-eu", accept_terms = true }
    acme_ovh_credentials = null
  }

  expect_failures = [var.acme]
}

run "rejects_ovh_credentials_for_an_existing_id" {
  command = plan

  variables {
    acme = { dns_authenticator_id = 913, accept_terms = true }
  }

  expect_failures = [var.acme_ovh_credentials]
}
