# Bootstrap root. Runs once, then stays frozen. See BACKEND.md.

terraform {
  # Exact pin, in step with the opentofu entry in mise.toml.
  required_version = "1.12.6"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "2.19.0"
    }
  }
}

provider "ovh" {
  # Credentials come from the environment, through the git-ignored .env.
}
