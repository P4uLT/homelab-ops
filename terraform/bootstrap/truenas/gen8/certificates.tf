locals {
  acme_directory = "https://acme-v02.api.letsencrypt.org/directory"

  acme_certificate_groups = {
    for cert in var.acme_enabled ? var.acme_certificates : [] :
    cert.name => cert... if try(cert.name != null && cert.common_name != null && alltrue([for name in cert.san : name != null]), false)
  }
  acme_certificates_by_name = {
    for name, entries in local.acme_certificate_groups : name => {
      common_name = entries[0].common_name
      san         = distinct(concat([entries[0].common_name], sort(tolist(entries[0].san))))
    } if length(entries) == 1
  }
}

resource "truenas_certificate" "request" {
  for_each = local.acme_certificates_by_name

  name             = "${var.acme.name_prefix}-${each.key}-csr"
  create_type      = "CERTIFICATE_CREATE_CSR"
  common           = each.value.common_name
  san              = each.value.san
  key_type         = "RSA"
  key_length       = 2048
  digest_algorithm = "SHA256"
  store_privatekey = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "truenas_certificate" "issued" {
  for_each = local.acme_certificates_by_name

  name               = "${var.acme.name_prefix}-${each.key}-acme"
  create_type        = "CERTIFICATE_CREATE_ACME"
  csr_id             = truenas_certificate.request[each.key].id
  acme_directory_uri = local.acme_directory
  tos                = var.acme.accept_terms
  renew_days         = 30

  # TrueNAS matches the bare CN and DNS:-prefixed SANs during issuance.
  dns_mapping = {
    for name in each.value.san :
    (name == each.value.common_name ? name : "DNS:${name}") => local.acme_dns_authenticator_id
  }

  lifecycle {
    prevent_destroy = true
  }
}
