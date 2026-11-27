resource "truenas_system_general" "acme_admin" {
  count = var.acme_assign_admin ? 1 : 0

  ui_certificate = truenas_certificate.admin_acme[0].id
}
