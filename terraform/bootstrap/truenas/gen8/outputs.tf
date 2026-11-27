output "api_key_value" {
  description = "API key for the Gen8 provisioning root. Stored in encrypted bootstrap state."
  value       = truenas_api_key.provisioner.key
  sensitive   = true
}

output "acme_admin_certificate_id" {
  description = "ID of the managed administration certificate, if enabled."
  value       = one(truenas_certificate.admin_acme[*].id)
}

output "acme_apps_certificate_id" {
  description = "ID of the managed wildcard certificate for Gen8 applications, if enabled."
  value       = one(truenas_certificate.apps_acme[*].id)
}
