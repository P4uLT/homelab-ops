variable "admin_access_key" {
  description = "Access key used by the RustFS provider. Reserved for administration."
  type        = string
  nullable    = false
}

variable "buckets" {
  description = "S3 buckets keyed by name, with quotas in GiB and optional bucket, versioning, user, and policy settings."
  type = map(object({
    quota_gib                      = number
    versioning                     = optional(bool)
    bucket_namespace               = optional(string)
    object_ownership               = optional(string)
    object_lock_enabled_for_bucket = optional(bool)
    create_bucket_configuration = optional(object({
      location_constraint = optional(string)
      tags                = optional(map(string))
    }))
    force_destroy             = optional(bool, false)
    user_name                 = optional(string)
    user_status               = optional(string, "enabled")
    additional_bucket_actions = optional(set(string), [])
    additional_object_actions = optional(set(string), [])
  }))
  nullable = false

  validation {
    condition = alltrue([
      for name in keys(var.buckets) : can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", name)) &&
      !strcontains(name, "..") && !can(regex("^[0-9]+(\\.[0-9]+){3}$", name))
    ])
    error_message = "Use bucket names of 3 to 63 lowercase letters, digits, dots, or hyphens. Start and end with a letter or digit. Don't use adjacent dots or IPv4 names."
  }

  validation {
    condition = alltrue([
      for bucket in values(var.buckets) : try(
        bucket.quota_gib > 0 && bucket.quota_gib < local.quota_limit_gib &&
        (bucket.quota_gib * local.bytes_per_gib) % 1 == 0,
        false
      )
    ])
    error_message = "Each quota_gib must convert to a positive whole number of bytes smaller than 2^63."
  }

  validation {
    condition = alltrue([
      for bucket in values(var.buckets) : try(
        length(setsubtract(bucket.additional_bucket_actions, local.allowed_bucket_actions)) == 0 &&
        length(setsubtract(bucket.additional_object_actions, local.allowed_object_actions)) == 0,
        false
      )
    ])
    error_message = "Use only supported S3 data actions under their bucket or object scope. Wildcards and bucket administration aren't allowed."
  }

  validation {
    condition = alltrue([
      for bucket in values(var.buckets) : try(contains(["enabled", "disabled"], bucket.user_status), false)
    ])
    error_message = "Set user_status to enabled or disabled."
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
      !contains([for credential in values(var.bucket_credentials) : credential.access_key], var.admin_access_key),
      false
    )
    error_message = "Use a distinct access key per bucket user. The admin access key is reserved."
  }
}
