variable "state_passphrase" {
  description = "Passphrase for the local state encryption. Source: TF_VAR_state_passphrase in .env.tf."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must hold at least 16 characters."
  }
}

variable "project_id" {
  description = "OVH Public Cloud project ID. Source: OVH_CLOUD_PROJECT_SERVICE in .env.account.ovh.tf."
  type        = string
}

variable "bucket_name" {
  description = "State bucket name. Source: TF_VAR_bucket_name in .env.tf."
  type        = string
}

variable "region" {
  description = "State bucket region, uppercase for the project API. Source: region in ovh.local.auto.tfvars. Use a 3-AZ region."
  type        = string
}
