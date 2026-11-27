locals {
  acme_existing_authenticator_id = try(var.acme.dns_authenticator_id, null)
  acme_manage_ovh                = var.acme_enabled && local.acme_existing_authenticator_id == null
  acme_dns_authenticator_id      = local.acme_manage_ovh ? one(truenas_acme_dns_authenticator.ovh[*].id) : local.acme_existing_authenticator_id
}

resource "truenas_acme_dns_authenticator" "ovh" {
  count = local.acme_manage_ovh ? 1 : 0

  name = "${var.acme.name_prefix}-ovh-dns01"
  attributes = jsonencode({
    authenticator = "OVH"
    endpoint      = var.acme.ovh_endpoint
  })
  attributes_secrets_wo         = jsonencode(var.acme_ovh_credentials)
  attributes_secrets_wo_version = var.acme_ovh_credentials_version

  lifecycle {
    prevent_destroy = true
  }
}
