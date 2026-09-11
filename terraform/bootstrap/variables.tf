variable "state_passphrase" {
  description = "Passphrase for the local state encryption. Source: TF_STATE_PASSPHRASE in .env, mapped by the tf tasks."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must hold at least 16 characters."
  }
}

variable "project_id" {
  description = "OVH Public Cloud project ID. Source: OVH_CLOUD_PROJECT_SERVICE in .env."
  type        = string
}

variable "bucket_name" {
  description = "State bucket name. Source: OVH_BUCKET in .env."
  type        = string
}

variable "region" {
  description = "OVH region of the state bucket, uppercase as the project API expects it. Source: OVH_REGION in .env. Use a 3-AZ region."
  type        = string
}
