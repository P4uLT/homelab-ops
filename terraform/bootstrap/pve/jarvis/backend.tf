terraform {
  # Remote, on the shared state bucket. Same partial config as every
  # S3 root: the OVH dialect facts live in terraform/backend.s3.ovh.hcl
  # and the bucket name reaches init through the tf tasks. The key
  # mirrors the root path, like every root: see BACKEND.md. No
  # circularity here, unlike bootstrap/ovh: the bucket predates this
  # root, so its state, which holds the token value, is remote,
  # versioned, and covered by the recovery kit.
  backend "s3" {
    key = "bootstrap/pve/jarvis/terraform.tfstate"
  }

  # Every root encrypts its state payload. This one holds the API token
  # value. TF_VAR_state_passphrase reaches this from .env.tf through
  # the tf tasks.
  # pi-lens-ignore: Terraform:unknown. OpenTofu-only block, unknown to the
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
