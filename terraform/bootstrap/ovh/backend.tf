terraform {
  # Local on purpose: this root creates the bucket that every other root
  # uses as its backend. State lands in terraform.tfstate beside these
  # files. See BACKEND.md.
  backend "local" {}

  # The S3 keys land in this state, so encryption is mandatory.
  # TF_VAR_state_passphrase reaches this from .env.tf through the tf tasks.
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
