mock_provider "truenas" {
  mock_resource "truenas_api_key" {
    defaults = { key = "mock-provisioner-key" }
  }
}

variables {
  acme_enabled      = false
  acme_assign_admin = false
  truenas_host      = "nas.example.net"
  truenas_api_key   = "mock-only"
  state_passphrase  = "mock-only-passphrase"
  pool              = { serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"] }
  groups            = {}
  users             = {}
  user_passwords    = {}

  provision_smb_shares   = false
  provision_dataset_acls = false
  provision_group_lookup = false
  provision_apps         = false
}

run "leaves_certificates_unmanaged_when_disabled" {
  command = plan

  assert {
    condition = (
      length(truenas_acme_dns_authenticator.ovh) == 0 &&
      length(truenas_certificate.admin_request) == 0 &&
      length(truenas_certificate.apps_request) == 0 &&
      length(truenas_certificate.admin_acme) == 0 &&
      length(truenas_certificate.apps_acme) == 0 &&
      output.acme_admin_certificate_id == null &&
      output.acme_apps_certificate_id == null
    )
    error_message = "Certificate management must be off by default."
  }
}

run "issues_two_separately_keyed_certificates" {
  command = plan

  variables {
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
    acme_ovh_credentials_version = 2
  }

  override_resource {
    target = truenas_acme_dns_authenticator.ovh
    values = { id = 42 }
  }

  override_resource {
    target = truenas_certificate.admin_request
    values = { id = 51 }
  }

  override_resource {
    target = truenas_certificate.apps_request
    values = { id = 52 }
  }

  override_resource {
    target = truenas_certificate.admin_acme
    values = { id = 101 }
  }

  override_resource {
    target = truenas_certificate.apps_acme
    values = { id = 202 }
  }

  assert {
    condition = (
      length(truenas_acme_dns_authenticator.ovh) == 1 &&
      jsondecode(nonsensitive(truenas_acme_dns_authenticator.ovh[0].attributes)) == {
        authenticator = "OVH"
        endpoint      = "ovh-eu"
      } &&
      truenas_acme_dns_authenticator.ovh[0].attributes_secrets_wo_version == 2
    )
    error_message = "Only the public settings belong in ordinary authenticator attributes."
  }

  assert {
    condition = (
      length(truenas_certificate.admin_request) == 1 &&
      length(truenas_certificate.apps_request) == 1 &&
      truenas_certificate.admin_request[0].common == "nas.example.net" &&
      tolist(truenas_certificate.admin_request[0].san) == tolist(["nas.example.net"]) &&
      truenas_certificate.apps_request[0].common == "*.apps.example.net" &&
      tolist(truenas_certificate.apps_request[0].san) == tolist(["*.apps.example.net"]) &&
      alltrue([
        for request in concat(truenas_certificate.admin_request, truenas_certificate.apps_request) :
        request.create_type == "CERTIFICATE_CREATE_CSR" &&
        request.key_type == "RSA" && request.key_length == 2048 &&
        request.digest_algorithm == "SHA256" && !request.store_privatekey
      ])
    )
    error_message = "Each signing request must use its own key and one name."
  }

  assert {
    condition = (
      length(truenas_certificate.admin_acme) == 1 &&
      length(truenas_certificate.apps_acme) == 1 &&
      truenas_certificate.admin_acme[0].csr_id == 51 &&
      truenas_certificate.apps_acme[0].csr_id == 52 &&
      truenas_certificate.admin_acme[0].dns_mapping["nas.example.net"] == 42 &&
      truenas_certificate.apps_acme[0].dns_mapping["*.apps.example.net"] == 42 &&
      alltrue([
        for cert in concat(truenas_certificate.admin_acme, truenas_certificate.apps_acme) :
        cert.create_type == "CERTIFICATE_CREATE_ACME" && length(cert.dns_mapping) == 1 &&
        cert.acme_directory_uri == "https://acme-v02.api.letsencrypt.org/directory" &&
        cert.renew_days == 30 && cert.tos
      ]) &&
      output.acme_admin_certificate_id == 101 && output.acme_apps_certificate_id == 202
    )
    error_message = "Each certificate must use its own request and the shared OVH authenticator."
  }

  assert {
    condition = toset(truenas_privilege.provisioner.roles) == toset([
      "DATASET_READ", "DATASET_WRITE", "SHARING_NFS_READ", "SHARING_NFS_WRITE", "SERVICE_READ"
    ])
    error_message = "Enabling certificate issuance must not expand the provisioning role."
  }

  assert {
    condition     = length(truenas_system_general.acme_admin) == 0
    error_message = "Issuance alone must not restart the administration service."
  }

  assert {
    condition = (
      truenas_acme_dns_authenticator.ovh[0].name == "truenas-ovh-dns01" &&
      truenas_certificate.admin_request[0].name == "truenas-admin-csr" &&
      truenas_certificate.apps_request[0].name == "truenas-apps-csr" &&
      truenas_certificate.admin_acme[0].name == "truenas-admin-acme" &&
      truenas_certificate.apps_acme[0].name == "truenas-apps-acme"
    )
    error_message = "Object names must use the certificate name prefix."
  }
}

run "binds_only_the_admin_certificate" {
  command = plan

  variables {
    truenas_host      = "nas.example.net:443"
    acme_enabled      = true
    acme_assign_admin = true
    acme = {
      name_prefix    = "storage-lab"
      admin_hostname = "nas.example.net"
      apps_domain    = "apps.example.net"
      ovh_endpoint   = "ovh-ca"
      accept_terms   = true
    }
    acme_ovh_credentials = {
      application_key    = "mock-application-key"
      application_secret = "mock-application-secret"
      consumer_key       = "mock-consumer-key"
    }
  }

  override_resource {
    target = truenas_certificate.admin_acme
    values = { id = 101 }
  }

  override_resource {
    target = truenas_certificate.apps_acme
    values = { id = 202 }
  }

  assert {
    condition     = truenas_system_general.acme_admin[0].ui_certificate == 101
    error_message = "Only the administration certificate may serve the management endpoint."
  }

  assert {
    condition = (
      truenas_acme_dns_authenticator.ovh[0].name == "storage-lab-ovh-dns01" &&
      truenas_certificate.admin_request[0].name == "storage-lab-admin-csr" &&
      truenas_certificate.apps_request[0].name == "storage-lab-apps-csr" &&
      truenas_certificate.admin_acme[0].name == "storage-lab-admin-acme" &&
      truenas_certificate.apps_acme[0].name == "storage-lab-apps-acme"
    )
    error_message = "Object names must use the certificate name prefix."
  }
}

run "uses_an_existing_dns_authenticator_without_ovh" {
  command = plan

  variables {
    acme_enabled = true
    acme = {
      admin_hostname       = "nas.example.net"
      apps_domain          = "apps.example.net"
      dns_authenticator_id = 913
      accept_terms         = true
    }
    acme_ovh_credentials = null
  }

  assert {
    condition = (
      length(truenas_acme_dns_authenticator.ovh) == 0 &&
      truenas_certificate.admin_acme[0].dns_mapping["nas.example.net"] == 913 &&
      truenas_certificate.apps_acme[0].dns_mapping["*.apps.example.net"] == 913
    )
    error_message = "Both orders must use the supplied ID without creating an OVH authenticator."
  }
}
