variable "pve_ssh_host" {
  type        = string
  description = "SSH address of the PVE node, from the node local var file."
}

variable "pve_ssh_user" {
  type        = string
  description = "SSH login on the PVE node."
}

variable "pve_ssh_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "pve_ssh_key_path" {
  type    = string
  default = ""
}

variable "pve_ssh_key_passphrase" {
  type      = string
  default   = ""
  sensitive = true
}

variable "pve_ssh_agent_auth" {
  type    = bool
  default = false
}

variable "artifact_storage" {
  type        = string
  description = "Storage that holds parent and output archives."
}

variable "artifact_dir" {
  type        = string
  description = "Filesystem path where the plugin writes artifacts."
}

variable "ct_storage" {
  type        = string
  description = "Node storage for the container root filesystem."
}

variable "ct_bridge" {
  type        = string
  description = "Node network bridge for the build container."
}

variable "image_id" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.image_id))
    error_message = "The image_id must be a lowercase name containing letters, numbers, and hyphens."
  }
}

variable "image_kind" {
  type = string

  validation {
    condition     = var.image_kind == "lxc"
    error_message = "The image_kind must be lxc for this backend."
  }
}

variable "os_id" {
  type = string
}

variable "os_major" {
  type = string
}

variable "arch" {
  type = string

  validation {
    condition     = var.arch == "amd64"
    error_message = "The arch must be amd64 for the supported recipes."
  }
}

variable "ansible_limit" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]*$", var.ansible_limit))
    error_message = "The ansible_limit must be a safe Ansible inventory name."
  }
}

variable "build_ctid" {
  type = string
}

variable "ct_memory" {
  type = number
}

variable "ct_cores" {
  type = number
}

variable "ct_rootfs_size" {
  type = string
}

variable "parent_archive" {
  type = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._+-]*_amd64\\.tar\\.zst$", var.parent_archive))
    error_message = "The parent_archive must be a safe amd64 archive basename."
  }
}

variable "build_id" {
  type = string

  validation {
    condition     = can(regex("^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.build_id))
    error_message = "The build_id must contain a UTC timestamp and canonical lowercase UUIDv4."
  }
}

variable "source_revision" {
  type = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.source_revision))
    error_message = "The source_revision must be a full lowercase Git commit ID."
  }
}

variable "manifest_path" {
  type = string

  validation {
    condition     = startswith(var.manifest_path, "/") && endswith(var.manifest_path, "/packer.json")
    error_message = "The manifest_path must be an absolute per-build packer.json path."
  }
}
