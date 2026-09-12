terraform {
  # Remote, on the shared state bucket. The bucket name reaches init
  # through the tf tasks, so it stays out of tracked files. The region
  # and the endpoint are generic provider facts. The key is a chosen
  # name, not a value derived from the directory path. See BACKEND.md.
  backend "s3" {
    key    = "jarvis"
    region = "eu-west-par"

    # The OVH region name is not an AWS region. The endpoint decides
    # where the calls go.
    skip_region_validation = true

    # OVH S3 has no STS. The static keys of .env.tf are the only
    # credential path.
    skip_credentials_validation = true

    endpoints = {
      s3 = "https://s3.eu-west-par.io.cloud.ovh.net"
    }

    # The lockfile needs conditional writes. The first plan is the test.
    # See BACKEND.md.
    use_lockfile = true
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
