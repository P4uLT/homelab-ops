terraform {
  required_version = "1.12.6"

  required_providers {
    truenas = {
      source  = "truenas/truenas"
      version = ">= 1.9.3"
    }
  }
}
