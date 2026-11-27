mock_provider "truenas" {
  mock_resource "truenas_api_key" {
    defaults = { key = "mock-provisioner-key" }
  }
}

variables {
  acme_enabled                = true
  acme_admin_certificate_name = null
  truenas_host                = "nas.example.net:443"
  truenas_api_key             = "mock-only"
  state_passphrase            = "mock-only-passphrase"
  pool                        = { serials = ["DRIVE-A", "DRIVE-B", "DRIVE-C", "DRIVE-D"] }
  groups                      = {}
  users                       = {}
  user_passwords              = {}

  provision_smb_shares   = false
  provision_dataset_acls = false
  provision_group_lookup = false
  provision_apps         = false

  acme = { ovh_endpoint = "ovh-eu", accept_terms = true }
  acme_certificates = [
    { name = "admin", common_name = "nas.example.net" },
    { name = "apps", common_name = "*.apps.example.net" },
    { name = "shared", common_name = "nas.example.net", san = ["*.apps.example.net", "nas.example.net"] },
  ]
  acme_ovh_credentials = {
    application_key    = "mock-application-key"
    application_secret = "mock-application-secret"
    consumer_key       = "mock-consumer-key"
  }
  acme_ovh_credentials_version = 2
}

run "leaves_certificates_unmanaged_when_disabled" {
  command = plan

  variables {
    acme_enabled         = false
    acme                 = null
    acme_certificates    = []
    acme_ovh_credentials = null
  }

  assert {
    condition = (
      length(truenas_acme_dns_authenticator.ovh) == 0 &&
      length(truenas_certificate.request) == 0 &&
      length(truenas_certificate.issued) == 0 &&
      length(truenas_system_general.acme_admin) == 0 &&
      length(output.acme_certificate_ids) == 0
    )
    error_message = "Disabled certificate management must not require credentials or create resources."
  }
}

run "issues_named_certificates" {
  command = plan

  override_resource {
    target = truenas_acme_dns_authenticator.ovh
    values = { id = 42 }
  }

  override_resource {
    target = truenas_certificate.request
    values = { id = 51 }
  }

  override_resource {
    target = truenas_certificate.issued
    values = { id = 101 }
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
    error_message = "Keep the existing OVH authenticator and its write-only credential version."
  }

  assert {
    condition = (
      toset(keys(truenas_certificate.request)) == toset(["admin", "apps", "shared"]) &&
      tolist(truenas_certificate.request["admin"].san) == tolist(["nas.example.net"]) &&
      tolist(truenas_certificate.request["apps"].san) == tolist(["*.apps.example.net"]) &&
      tolist(truenas_certificate.request["shared"].san) == tolist(["nas.example.net", "*.apps.example.net"]) &&
      alltrue([
        for cert in var.acme_certificates :
        truenas_certificate.request[cert.name].common == cert.common_name
      ]) &&
      alltrue([
        for name, request in truenas_certificate.request :
        request.name == "truenas-${name}-csr" &&
        request.create_type == "CERTIFICATE_CREATE_CSR" &&
        request.key_type == "RSA" && request.key_length == 2048 &&
        request.digest_algorithm == "SHA256" && !request.store_privatekey
      ])
    )
    error_message = "Each named request must include its CN, unique SANs, and its own on-box key."
  }

  assert {
    condition = (
      toset(keys(truenas_certificate.issued)) == toset(["admin", "apps", "shared"]) &&
      truenas_certificate.issued["admin"].dns_mapping == tomap({ "nas.example.net" = 42 }) &&
      truenas_certificate.issued["apps"].dns_mapping == tomap({ "*.apps.example.net" = 42 }) &&
      truenas_certificate.issued["shared"].dns_mapping == tomap({ "nas.example.net" = 42, "DNS:*.apps.example.net" = 42 }) &&
      alltrue([
        for name, cert in truenas_certificate.issued :
        cert.name == "truenas-${name}-acme" &&
        cert.csr_id == truenas_certificate.request[name].id &&
        cert.create_type == "CERTIFICATE_CREATE_ACME" &&
        cert.acme_directory_uri == "https://acme-v02.api.letsencrypt.org/directory" &&
        cert.renew_days == 30 && cert.tos
      ]) &&
      output.acme_certificate_ids == tomap({ admin = 101, apps = 101, shared = 101 })
    )
    error_message = "Issue each certificate from its own request, map every DNS name, and expose only numeric IDs."
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
}

run "keeps_addresses_and_attributes_when_reordered" {
  command = plan

  variables {
    acme_certificates = [
      { name = "shared", common_name = "nas.example.net", san = ["nas.example.net", "*.apps.example.net"] },
      { name = "apps", common_name = "*.apps.example.net" },
      { name = "admin", common_name = "nas.example.net" },
    ]
  }

  assert {
    condition = (
      toset(keys(truenas_certificate.issued)) == toset(["admin", "apps", "shared"]) &&
      { for name, request in truenas_certificate.request : name => tolist(request.san) } == {
        admin  = tolist(["nas.example.net"])
        apps   = tolist(["*.apps.example.net"])
        shared = tolist(["nas.example.net", "*.apps.example.net"])
      }
    )
    error_message = "Reordering the list must preserve named resource keys and their SANs."
  }
}

run "binds_the_selected_certificate_by_management_san" {
  command = plan

  variables {
    acme_admin_certificate_name = "shared"
    acme                        = { name_prefix = "storage-lab", ovh_endpoint = "ovh-ca", accept_terms = true }
    acme_certificates = [
      { name = "admin", common_name = "nas.example.net" },
      { name = "shared", common_name = "*.apps.example.net", san = ["nas.example.net"] },
    ]
  }

  override_resource {
    target = truenas_certificate.issued
    values = { id = 303 }
  }

  assert {
    condition = (
      truenas_system_general.acme_admin[0].ui_certificate == 303 &&
      truenas_acme_dns_authenticator.ovh[0].name == "storage-lab-ovh-dns01" &&
      truenas_certificate.request["shared"].name == "storage-lab-shared-csr" &&
      truenas_certificate.issued["shared"].name == "storage-lab-shared-acme"
    )
    error_message = "Bind the selected certificate instead of assuming that the first entry or CN serves management."
  }
}

run "uses_an_existing_dns_authenticator_without_ovh" {
  command = plan

  variables {
    acme                 = { dns_authenticator_id = 913, accept_terms = true }
    acme_ovh_credentials = null
  }

  assert {
    condition = (
      length(truenas_acme_dns_authenticator.ovh) == 0 &&
      truenas_certificate.issued["shared"].dns_mapping == tomap({ "nas.example.net" = 913, "DNS:*.apps.example.net" = 913 })
    )
    error_message = "Use the supplied authenticator ID for every name without creating an OVH authenticator."
  }
}
