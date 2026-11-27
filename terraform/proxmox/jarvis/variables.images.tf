variable "vm_image_downloads" {
  description = "Versioned VM images downloaded and managed by Terraform, keyed by image label."
  type = map(object({
    url       = string
    sha256    = string
    file_name = string
    storage   = string
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for image in values(var.vm_image_downloads) :
      can(regex("^https://[^[:space:]]+[.]qcow2[.]xz$", image.url)) &&
      can(regex("^[0-9a-fA-F]{64}$", image.sha256)) &&
      can(regex("^[A-Za-z0-9_.-]+-[0-9]+[.][0-9]+([.][0-9]+)?[.]qcow2[.]img$", image.file_name))
    ])
    error_message = "Downloads require an HTTPS QCOW2.XZ URL, a 64-character SHA256, and a versioned QCOW2.IMG filename."
  }
}

variable "vm_image_files" {
  description = "Existing VM images managed outside Terraform, keyed by image label."
  type = map(object({
    file_name    = string
    storage      = string
    content_type = optional(string, "iso")
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for image in values(var.vm_image_files) :
      contains(["iso", "import"], image.content_type) &&
      can(regex(image.content_type == "import" ? "^[A-Za-z0-9_.-]+-[0-9]+[.][0-9]+([.][0-9]+)?[.]qcow2$" : "^[A-Za-z0-9_.-]+-[0-9]+[.][0-9]+([.][0-9]+)?[.]qcow2[.]img$", image.file_name))
    ])
    error_message = "External images require a versioned QCOW2 file in Import content, or a versioned QCOW2.IMG file in ISO content."
  }
}
