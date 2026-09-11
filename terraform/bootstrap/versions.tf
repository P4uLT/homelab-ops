# State backend bootstrap. This root runs once, then stays frozen.
# See BACKEND.md for the design and the recovery path.

terraform {
  # Exact pin, like every other dependency. Keep in step with the
  # opentofu entry in mise.toml.
  required_version = "1.12.6"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "2.19.0"
    }
  }
}

provider "ovh" {
  # The API credentials come from the environment: OVH_ENDPOINT,
  # OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY.
  # They live in the git-ignored .env file that mise loads.
}
