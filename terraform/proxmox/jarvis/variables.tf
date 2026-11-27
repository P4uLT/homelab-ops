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
}

variable "pve_api_token" {
  description = "PVE API token of this node. Source: jarvis.local.auto.tfvars, git-ignored."
  type        = string
  sensitive   = true
}

variable "pve_ssh_username" {
  description = "Node SSH login for VM disk import through ssh-agent. Null disables SSH configuration."
  type        = string
  default     = null

  validation {
    condition     = var.pve_ssh_username == null ? true : length(trimspace(var.pve_ssh_username)) > 0
    error_message = "pve_ssh_username must be null or a nonempty SSH login."
  }
}
