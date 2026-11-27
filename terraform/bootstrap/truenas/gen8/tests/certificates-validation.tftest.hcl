mock_provider "truenas" {}

variables {
  acme_assign_admin = false
  truenas_host      = "nas.example.net"
  truenas_api_key   = "mock-only"
  state_passphrase  = "mock-only-passphrase"
  pool              = { serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"] }
  groups            = {}
  users             = {}
  user_passwords    = {}

  acme_enabled = true
  acme = {
    admin_hostname = "nas.example.net"
    apps_domain    = "apps.example.net"
    ovh_endpoint   = "ovh-eu"
    accept_terms   = true
  }
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
    acme = { admin_hostname = "nas.example.net", apps_domain = "apps.example.net", ovh_endpoint = "ovh-eu", accept_terms = false }
  }

  expect_failures = [var.acme]
}

run "rejects_an_unsupported_ovh_endpoint" {
  command = plan

  variables {
    acme = { admin_hostname = "nas.example.net", apps_domain = "apps.example.net", ovh_endpoint = "unsupported", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_a_hostname_with_a_scheme_and_port" {
  command = plan

  variables {
    acme = { admin_hostname = "https://nas.example.net:443", apps_domain = "apps.example.net", ovh_endpoint = "ovh-eu", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_a_hostname_with_an_empty_label" {
  command = plan

  variables {
    acme = { admin_hostname = "nas..example.net", apps_domain = "apps.example.net", ovh_endpoint = "ovh-eu", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_an_address_as_the_admin_hostname" {
  command = plan

  variables {
    acme = { admin_hostname = "192.0.2.10", apps_domain = "apps.example.net", ovh_endpoint = "ovh-eu", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_a_preexpanded_wildcard" {
  command = plan

  variables {
    acme = { admin_hostname = "nas.example.net", apps_domain = "*.apps.example.net", ovh_endpoint = "ovh-eu", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_a_trailing_dot_in_the_apps_domain" {
  command = plan

  variables {
    acme = { admin_hostname = "nas.example.net", apps_domain = "apps.example.net.", ovh_endpoint = "ovh-eu", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_admin_below_the_application_suffix" {
  command = plan

  variables {
    acme = { admin_hostname = "nas.apps.example.net", apps_domain = "apps.example.net", ovh_endpoint = "ovh-eu", accept_terms = true }
  }

  expect_failures = [var.acme]
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
    acme_enabled      = false
    acme_assign_admin = true
  }

  expect_failures = [var.acme_assign_admin]
}

run "rejects_binding_when_the_provider_uses_another_hostname" {
  command = plan

  variables {
    truenas_host      = "old-nas.example.net"
    acme_assign_admin = true
  }

  expect_failures = [var.acme_assign_admin]
}

run "rejects_a_prefix_with_a_dns_separator" {
  command = plan

  variables {
    acme = { name_prefix = "storage.lab", admin_hostname = "nas.example.net", apps_domain = "apps.example.net", ovh_endpoint = "ovh-eu", accept_terms = true }
  }

  expect_failures = [var.acme]
}

run "rejects_a_fractional_authenticator_id" {
  command = plan

  variables {
    acme                 = { admin_hostname = "nas.example.net", apps_domain = "apps.example.net", dns_authenticator_id = 1.5, accept_terms = true }
    acme_ovh_credentials = null
  }

  expect_failures = [var.acme]
}

run "rejects_combining_an_existing_id_with_an_ovh_endpoint" {
  command = plan

  variables {
    acme                 = { admin_hostname = "nas.example.net", apps_domain = "apps.example.net", dns_authenticator_id = 913, ovh_endpoint = "ovh-eu", accept_terms = true }
    acme_ovh_credentials = null
  }

  expect_failures = [var.acme]
}

run "rejects_ovh_credentials_for_an_existing_id" {
  command = plan

  variables {
    acme = { admin_hostname = "nas.example.net", apps_domain = "apps.example.net", dns_authenticator_id = 913, accept_terms = true }
  }

  expect_failures = [var.acme_ovh_credentials]
}
