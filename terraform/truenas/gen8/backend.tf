terraform {
  # Remote, on the shared state bucket. Each TrueNAS root keeps its own key so
  # a plan on one root never touches the other's state. The bucket name and the
  # OVH dialect facts come from the tf tasks and terraform/backend.s3.ovh.hcl.
  # State and plan files are encrypted with the passphrase from .env.tf.
  backend "s3" {
    key = "truenas/gen8/terraform.tfstate"
  }

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
