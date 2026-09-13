variable "state_passphrase" {
  description = "Passphrase for the state encryption. Source: TF_VAR_state_passphrase in .env.tf."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must hold at least 16 characters."
  }
}

variable "pve_endpoint" {
  description = "PVE API endpoint of this node. Source: jarvis.local.auto.tfvars, git-ignored."
  type        = string

  validation {
    condition     = startswith(var.pve_endpoint, "https://")
    error_message = "pve_endpoint must be an https URL."
  }
}

variable "pve_username" {
  description = "Account the root authenticates as. The default is the built-in PVE admin account, the only one that can mint tokens out of the box."
  type        = string
  default     = "root@pam"
}

variable "pve_password" {
  description = "Password of the minting account, a one-time credential. Source: jarvis.local.auto.tfvars, git-ignored."
  type        = string
  sensitive   = true
}
