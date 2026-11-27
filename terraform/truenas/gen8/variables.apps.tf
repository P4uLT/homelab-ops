variable "rustfs_app_enabled" {
  description = "Install the RustFS catalog application. Turning it off after install plans removal."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition = !var.rustfs_app_enabled || try(
      contains(keys(var.datasets), "rustfs") &&
      var.datasets["rustfs"].name == var.rustfs_app_dataset &&
      var.datasets["rustfs"].share_type == "APPS" &&
      length(trimspace(var.rustfs_app_dataset)) > 0,
      false
    )
    error_message = "Enable the app only with a \"rustfs\" datasets entry named by rustfs_app_dataset with share_type = \"APPS\"."
  }

  validation {
    condition = !var.rustfs_app_enabled || try(
      var.rustfs_app_version != null &&
      length(var.rustfs_app_version) > 0 &&
      trimspace(var.rustfs_app_version) == var.rustfs_app_version &&
      can(regex("^[0-9]+(\\.[0-9]+)+$", var.rustfs_app_version)),
      false
    )
    error_message = "Set rustfs_app_version to a pinned catalog version such as 1.1.47."
  }

  validation {
    condition = !var.rustfs_app_enabled || try(
      length(var.rustfs_app_access_key) >= 3 &&
      length(var.rustfs_app_access_key) <= 20 &&
      length(var.rustfs_app_secret_key) >= 8 &&
      length(var.rustfs_app_secret_key) <= 40,
      false
    )
    error_message = "Set rustfs_app_access_key (3 to 20 characters) and rustfs_app_secret_key (8 to 40 characters)."
  }

  validation {
    condition = !var.rustfs_app_enabled || try(
      var.rustfs_app_certificate_id > 0 &&
      floor(var.rustfs_app_certificate_id) == var.rustfs_app_certificate_id,
      false
    )
    error_message = "Set rustfs_app_certificate_id to the positive ID of an existing TrueNAS certificate."
  }
}

variable "rustfs_app_version" {
  description = "Catalog chart version to install. Read the offered version from the TrueNAS catalog."
  type        = string
  default     = null
}

variable "rustfs_app_dataset" {
  description = "Dataset holding the RustFS data, as a dataset name under tank/."
  type        = string
  default     = "tank/rustfs"
  nullable    = false
}

variable "rustfs_app_api_port" {
  description = "Published HTTPS API port of the RustFS application."
  type        = number
  default     = 30292
  nullable    = false

  validation {
    condition = (
      var.rustfs_app_api_port >= 1 &&
      var.rustfs_app_api_port <= 65535 &&
      floor(var.rustfs_app_api_port) == var.rustfs_app_api_port
    )
    error_message = "rustfs_app_api_port must be a whole number from 1 to 65535."
  }

  validation {
    condition     = var.rustfs_app_api_port != var.rustfs_app_web_port
    error_message = "rustfs_app_api_port and rustfs_app_web_port must differ."
  }
}

variable "rustfs_app_web_port" {
  description = "Console port of the RustFS application. The chart leaves it unpublished."
  type        = number
  default     = 30293
  nullable    = false

  validation {
    condition = (
      var.rustfs_app_web_port >= 1 &&
      var.rustfs_app_web_port <= 65535 &&
      floor(var.rustfs_app_web_port) == var.rustfs_app_web_port
    )
    error_message = "rustfs_app_web_port must be a whole number from 1 to 65535."
  }
}

variable "rustfs_app_certificate_id" {
  description = "TrueNAS certificate ID for the RustFS API. Without it the chart serves HTTP."
  type        = number
  default     = null
}

variable "rustfs_app_access_key" {
  description = "RustFS admin access key, minted outside Terraform."
  type        = string
  default     = null
  sensitive   = true
}

variable "rustfs_app_secret_key" {
  description = "RustFS admin secret key, minted outside Terraform."
  type        = string
  default     = null
  sensitive   = true
}
