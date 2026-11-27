terraform {
  required_version = ">= 1.12.6"

  required_providers {
    rustfs = {
      source  = "caberdo/rustfs"
      version = ">= 0.10.0, < 0.11.0"
    }
  }
}
