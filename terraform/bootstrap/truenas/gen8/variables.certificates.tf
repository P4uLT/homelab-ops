variable "acme_enabled" {
  description = "Issue and renew the administration and application certificates on TrueNAS."
  type        = bool
  default     = false
  nullable    = false
}

variable "acme_assign_admin" {
  description = "Bind the issued administration certificate to the TrueNAS web interface."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.acme_assign_admin || var.acme_enabled
    error_message = "Set acme_enabled before assigning the administration certificate."
  }

  validation {
    condition = !var.acme_assign_admin || !var.acme_enabled || try(
      lower(split(":", var.truenas_host)[0]) == var.acme.admin_hostname, false
    )
    error_message = "Set truenas_host to the administration certificate hostname before enabling acme_assign_admin."
  }
}

variable "acme" {
  description = "Names, DNS authenticator settings, and Let's Encrypt terms acceptance for native certificate issuance."
  type = object({
    name_prefix          = optional(string, "truenas")
    admin_hostname       = string
    apps_domain          = string
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

  validation {
    condition = var.acme == null || try(
      length(var.acme.admin_hostname) <= 64 && length(var.acme.apps_domain) <= 62 &&
      alltrue([
        for name in [var.acme.admin_hostname, var.acme.apps_domain] :
        can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\\.[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", name))
      ]), false
    )
    error_message = "Use lowercase DNS names without a scheme, port, wildcard, or trailing dot. Admin names allow up to 64 characters and app domains allow up to 62."
  }

  validation {
    condition = var.acme == null || try(
      var.acme.admin_hostname != var.acme.apps_domain &&
      !endswith(var.acme.admin_hostname, ".${var.acme.apps_domain}"), false
    )
    error_message = "Keep the administration hostname outside the application domain."
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
