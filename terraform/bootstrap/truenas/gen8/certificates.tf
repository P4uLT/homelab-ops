locals {
  acme_apps_wildcard = var.acme == null ? null : "*.${var.acme.apps_domain}"
  acme_directory     = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "truenas_certificate" "admin_request" {
  count = var.acme_enabled ? 1 : 0

  name             = "${var.acme.name_prefix}-admin-csr"
  create_type      = "CERTIFICATE_CREATE_CSR"
  common           = var.acme.admin_hostname
  san              = [var.acme.admin_hostname]
  key_type         = "RSA"
  key_length       = 2048
  digest_algorithm = "SHA256"
  store_privatekey = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "truenas_certificate" "apps_request" {
  count = var.acme_enabled ? 1 : 0

  name             = "${var.acme.name_prefix}-apps-csr"
  create_type      = "CERTIFICATE_CREATE_CSR"
  common           = local.acme_apps_wildcard
  san              = [local.acme_apps_wildcard]
  key_type         = "RSA"
  key_length       = 2048
  digest_algorithm = "SHA256"
  store_privatekey = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "truenas_certificate" "admin_acme" {
  count = var.acme_enabled ? 1 : 0

  name               = "${var.acme.name_prefix}-admin-acme"
  create_type        = "CERTIFICATE_CREATE_ACME"
  csr_id             = truenas_certificate.admin_request[0].id
  acme_directory_uri = local.acme_directory
  tos                = var.acme.accept_terms
  renew_days         = 30
  dns_mapping        = { (var.acme.admin_hostname) = local.acme_dns_authenticator_id }

  lifecycle {
    prevent_destroy = true
  }
}

resource "truenas_certificate" "apps_acme" {
  count = var.acme_enabled ? 1 : 0

  name               = "${var.acme.name_prefix}-apps-acme"
  create_type        = "CERTIFICATE_CREATE_ACME"
  csr_id             = truenas_certificate.apps_request[0].id
  acme_directory_uri = local.acme_directory
  tos                = var.acme.accept_terms
  renew_days         = 30
  dns_mapping        = { (local.acme_apps_wildcard) = local.acme_dns_authenticator_id }

  lifecycle {
    prevent_destroy = true
  }
}
