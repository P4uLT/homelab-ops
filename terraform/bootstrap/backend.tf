terraform {
  # Deliberately local. This root has no remote backend: it creates the
  # bucket that every other root uses as their backend. The state file
  # lands as terraform.tfstate next to these files.
  backend "local" {}

  # OpenTofu native state encryption. The passphrase arrives through
  # TF_VAR_state_passphrase, mapped from .env by the tf tasks (16
  # characters minimum). The S3 credentials land in this state, so
  # encryption is mandatory, not optional.
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
