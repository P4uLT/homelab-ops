resource "truenas_system_general" "acme_admin" {
  count = try(contains(keys(local.acme_certificates_by_name), var.acme_admin_certificate_name), false) ? 1 : 0

  ui_certificate = truenas_certificate.issued[var.acme_admin_certificate_name].id
}
