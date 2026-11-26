variable "state_passphrase" {
  description = "Passphrase from TF_VAR_state_passphrase."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must hold at least 16 characters."
  }
}

variable "rustfs_endpoint" {
  description = "RustFS S3 API endpoint over HTTPS. No credentials, path, query, or fragment."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://[^/?#@]+$", var.rustfs_endpoint))
    error_message = "Use an https:// endpoint with a host and an optional port. Credentials, path, query, and fragment aren't allowed."
  }
}

variable "rustfs_access_key" {
  description = "RustFS admin access key. The same pair as the TrueNAS root."
  type        = string
  nullable    = false
}

variable "rustfs_secret_key" {
  description = "RustFS admin secret key. The same pair as the TrueNAS root."
  type        = string
  nullable    = false
  sensitive   = true
}

variable "buckets" {
  description = "S3 buckets keyed by name, each with its quota in bytes and optional versioning."
  type = map(object({
    quota_bytes = number
    versioning  = optional(bool)
  }))
  nullable = false

  validation {
    condition = try(
      alltrue([
        for name in ["k8s-backups", "wal-g", "loki"] : contains(keys(var.buckets), name)
      ]) &&
      alltrue([
        for bucket in values(var.buckets) :
        bucket.quota_bytes > 0 && floor(bucket.quota_bytes) == bucket.quota_bytes
      ]),
      false
    )
    error_message = "Declare the k8s-backups, wal-g, and loki buckets, each with a positive whole-byte quota."
  }
}

variable "bucket_credentials" {
  description = "IAM keys per bucket, keyed by the same bucket names."
  type = map(object({
    access_key = string
    secret_key = string
  }))
  nullable  = false
  sensitive = true

  validation {
    condition = try(
      length(setsubtract(keys(var.buckets), keys(var.bucket_credentials))) == 0 &&
      length(setsubtract(keys(var.bucket_credentials), keys(var.buckets))) == 0,
      false
    )
    error_message = "Give every bucket exactly one bucket_credentials entry, and no entry without a bucket."
  }

  validation {
    condition = try(alltrue([
      for credential in values(var.bucket_credentials) :
      length(credential.access_key) >= 3 &&
      length(credential.access_key) <= 20 &&
      trimspace(credential.access_key) == credential.access_key &&
      length(credential.secret_key) >= 8 &&
      length(credential.secret_key) <= 40
    ]), false)
    error_message = "Give every bucket user an access key of 3 to 20 characters and a secret key of 8 to 40 characters."
  }

  validation {
    condition = try(
      length(distinct([for credential in values(var.bucket_credentials) : credential.access_key])) == length(var.bucket_credentials) &&
      !contains([for credential in values(var.bucket_credentials) : credential.access_key], var.rustfs_access_key),
      false
    )
    error_message = "Use a distinct access key per bucket user. The admin access key is reserved."
  }
}
