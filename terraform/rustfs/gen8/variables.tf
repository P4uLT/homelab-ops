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
  description = "RustFS S3 API endpoint as host[:port] or an origin URL. No credentials, path, query, or fragment."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(regex("^(https?://)?([[:alnum:].-]+|\\[[[:xdigit:]:.]+\\])(:[0-9]+)?$", var.rustfs_endpoint)) &&
      (!startswith(var.rustfs_endpoint, "http://") || !var.rustfs_ssl) &&
      (!startswith(var.rustfs_endpoint, "https://") || var.rustfs_ssl)
    )
    error_message = "Use a host with an optional port. If supplied, the URL scheme must match rustfs_ssl. Omit credentials, path, query, and fragment."
  }
}

variable "rustfs_ssl" {
  description = "Use TLS for the RustFS connection. The endpoint scheme, if present, must agree."
  type        = bool
  default     = true
  nullable    = false
}

variable "rustfs_insecure" {
  description = "Skip verification of the RustFS server certificate. For isolated tests only."
  type        = bool
  default     = false
  nullable    = false
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

# The catalog module owns the schema so new fields need no root changes.
variable "buckets" {
  description = "Bucket settings passed to the RustFS catalog module."
  type        = any
  nullable    = false
}

variable "bucket_credentials" {
  description = "Per-bucket credentials passed to the RustFS catalog module."
  type        = any
  nullable    = false
  sensitive   = true
}
