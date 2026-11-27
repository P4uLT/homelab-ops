output "api_key_value" {
  description = "API key for the Gen8 provisioning root. Stored in encrypted bootstrap state."
  value       = truenas_api_key.provisioner.key
  sensitive   = true
}

output "acme_certificate_ids" {
  description = "IDs of issued certificates by input name."
  value       = tomap({ for name, certificate in truenas_certificate.issued : name => certificate.id })
}
