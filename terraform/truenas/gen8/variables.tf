variable "state_passphrase" {
  description = "Passphrase from TF_VAR_state_passphrase."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must hold at least 16 characters."
  }
}

variable "truenas_host" {
  description = "TrueNAS management hostname or address, with an optional port."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([A-Za-z0-9][A-Za-z0-9.-]*|\\[[0-9A-Fa-f:]+\\])(:[0-9]+)?$", var.truenas_host))
    error_message = "Use a hostname or address without a scheme or path. Enclose IPv6 addresses in brackets."
  }
}

variable "truenas_api_key" {
  description = "TrueNAS API key for this root."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "truenas_ca_cert" {
  description = "Path to a PEM CA certificate for a private CA."
  type        = string
  default     = null
}
