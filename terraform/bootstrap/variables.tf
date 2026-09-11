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
  description = "Primary state bucket name. Source: OVH_BUCKET in .env."
  type        = string
}

variable "region" {
  description = "OVH region of the primary state bucket. Source: OVH_REGION in .env. Prefer a 3-AZ region."
  type        = string
}

variable "replica_bucket_name" {
  description = "Replica bucket name for the cross-region copy. Source: OVH_REPLICA_BUCKET in .env."
  type        = string
}

variable "replica_region" {
  description = "OVH region of the replica bucket. Source: OVH_REPLICA_REGION in .env. Must differ from region."
  type        = string

  validation {
    condition     = var.replica_region != var.region
    error_message = "replica_region must differ from region. A copy in the same region shares the failure domain."
  }
}