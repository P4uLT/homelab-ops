# The mint. The value is readable at creation only. Copy it to the
# jarvis root tfvars, the same flow as the S3 keys of bootstrap/ovh.
output "token_id" {
  description = "Full token identifier, e.g. terraform-prov@pve!tf."
  value       = proxmox_virtual_environment_user_token.tf.id
}

output "token_value" {
  description = "Token secret. Populated at creation only; later plans keep the state value."
  value       = proxmox_virtual_environment_user_token.tf.value
  sensitive   = true
}
