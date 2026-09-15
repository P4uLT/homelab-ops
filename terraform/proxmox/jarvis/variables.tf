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

variable "tf_test_ipv4" {
  description = "Static IPv4 of the tf-test workload, in CIDR form and with its gateway. Null keeps DHCP. Source: jarvis.local.auto.tfvars, git-ignored."
  type = object({
    address = string
    gateway = optional(string)
  })
  default = null
}
