terraform {
  # Remote, on the shared state bucket. Only the key lives here: the
  # bucket name reaches init through the tf tasks, and the OVH dialect
  # facts (region, endpoint, validation skips, lockfile) come from the
  # shared terraform/backend.s3.ovh.hcl partial config. The key mirrors
  # the path under terraform/. See BACKEND.md.
  backend "s3" {
    key = "proxmox/jarvis/terraform.tfstate"
  }

  # Every root encrypts its state payload, so a root can start to hold
  # secrets at any time. TF_VAR_state_passphrase reaches this from .env.tf
  # through the tf tasks.
  # pi-lens-ignore: Terraform:unknown — OpenTofu-only block, unknown to the
  # Terraform schema; `tofu validate` is authoritative.
  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}
