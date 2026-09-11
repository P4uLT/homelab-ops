variable "state_passphrase" {
  description = "Passphrase for the local state encryption. Source: TF_STATE_PASSPHRASE in .env, mapped by the tf tasks. 16 characters minimum."
  type        = string
  sensitive   = true
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
  description = "OVH region of the state bucket. Source: OVH_REGION in .env."
  type        = string
}
