# This root mints the workload token. PVE returns its secret only at creation.
# Terraform state retains it for this output. Copy both values to the Jarvis
# root tfvars.
output "token_id" {
  description = "Full token identifier, for example terraform-prov@pve!tf."
  value       = proxmox_user_token.tf.id
}

output "token_value" {
  description = "Token secret. Populated at creation only; later plans keep the state value."
  value       = proxmox_user_token.tf.value
  sensitive   = true
}
