output "api_key_value" {
  description = "API key for the Gen8 provisioning root. Stored in encrypted bootstrap state."
  value       = truenas_api_key.provisioner.key
  sensitive   = true
}
