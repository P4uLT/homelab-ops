locals {
  acme_dns_name_pattern = "^(\\*\\.)?[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\\.[a-z]([a-z0-9-]{0,61}[a-z0-9])?$"
}

variable "acme_enabled" {
  description = "Issue and renew the configured certificates on TrueNAS."
  type        = bool
  default     = false
  nullable    = false
}

variable "acme_certificates" {
  description = "Named certificates to issue. Each common name also becomes a subject alternative name."
  type = list(object({
    name        = string
    common_name = string
    san         = optional(set(string), [])
  }))
  default  = []
  nullable = false

  validation {
    condition     = !var.acme_enabled || length(var.acme_certificates) > 0
    error_message = "List at least one certificate when ACME is enabled."
  }

  validation {
    condition = try(
      length(distinct([for cert in var.acme_certificates : cert.name])) == length(var.acme_certificates) &&
      alltrue([
        for cert in var.acme_certificates :
        can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", cert.name)) &&
        length("${try(var.acme.name_prefix, "truenas")}-${cert.name}-acme") <= 64
      ]), false
    )
    error_message = "Use unique lowercase certificate names with letters, digits, or dashes. Keep the generated TrueNAS object name within 64 characters."
  }

  validation {
    condition = alltrue([
      for cert in var.acme_certificates : try(
        length(cert.common_name) <= 64 && can(regex(local.acme_dns_name_pattern, cert.common_name)) &&
        alltrue([for name in cert.san : try(length(name) <= 253 && can(regex(local.acme_dns_name_pattern, name)), false)]),
        false
      )
    ])
    error_message = "Use bare lowercase DNS names or leftmost-label wildcards. Common names allow up to 64 characters and alternative names up to 253."
  }
}

variable "acme_admin_certificate_name" {
  description = "Name of the issued certificate to bind to the web interface. Null leaves the binding unmanaged."
  type        = string
  default     = null

  validation {
    condition = var.acme_admin_certificate_name == null || (
      var.acme_enabled && anytrue([
        for cert in var.acme_certificates : try(
          cert.name == var.acme_admin_certificate_name &&
          contains(concat([cert.common_name], tolist(cert.san)), lower(split(":", var.truenas_host)[0])), false
        )
      ])
    )
    error_message = "Enable ACME and select a listed certificate that includes the exact truenas_host hostname."
  }
}

variable "acme" {
  description = "Names, DNS authenticator settings, and Let's Encrypt terms acceptance for native certificate issuance."
  type = object({
    name_prefix          = optional(string, "truenas")
    dns_authenticator_id = optional(number)
    ovh_endpoint         = optional(string)
    accept_terms         = bool
  })
  default = null

  validation {
    condition     = !var.acme_enabled || var.acme != null
    error_message = "Set acme when acme_enabled is true."
  }

  validation {
    condition     = var.acme == null || try(can(regex("^[a-z0-9]([a-z0-9-]{0,52}[a-z0-9])?$", var.acme.name_prefix)), false)
    error_message = "Use a name_prefix of 1 to 54 lowercase letters, digits, or dashes. Start and end with a letter or digit."
  }

  validation {
    condition     = var.acme == null || try(var.acme.accept_terms == true, false)
    error_message = "Accept the Let's Encrypt terms."
  }

  validation {
    condition = var.acme == null || try(
      var.acme.dns_authenticator_id == null
      ? contains(["ovh-eu", "ovh-ca"], var.acme.ovh_endpoint)
      : (var.acme.dns_authenticator_id > 0 &&
        floor(var.acme.dns_authenticator_id) == var.acme.dns_authenticator_id &&
      var.acme.ovh_endpoint == null),
      false
    )
    error_message = "Set either an OVH endpoint (ovh-eu or ovh-ca) or the positive integer ID of an existing DNS authenticator."
  }

}

variable "acme_ovh_credentials" {
  description = "Dedicated OVH DNS credentials passed to the TrueNAS write-only authenticator fields."
  type = object({
    application_key    = string
    application_secret = string
    consumer_key       = string
  })
  default   = null
  sensitive = true
  ephemeral = true

  validation {
    condition = !var.acme_enabled || var.acme == null || try(
      var.acme.dns_authenticator_id != null
      ? var.acme_ovh_credentials == null
      : alltrue([for field in var.acme_ovh_credentials : length(trimspace(field)) > 0]),
      false
    )
    error_message = "Supply all three OVH credentials for a managed authenticator. Omit them when using an existing ID."
  }
}

variable "acme_ovh_credentials_version" {
  description = "Increment this version when replacing the OVH DNS credentials."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.acme_ovh_credentials_version > 0 && floor(var.acme_ovh_credentials_version) == var.acme_ovh_credentials_version
    error_message = "Set acme_ovh_credentials_version to a positive integer."
  }
}
