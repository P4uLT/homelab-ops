# Debian 13 standard, hardened. The base every other image builds on, and
# the first link of the chain: the name it leaves is the prefix the next
# image extends.

variable "base_build" {
  type        = number
  default     = 1
  description = "Build number. Bump it when the image content changes, never to rebuild the same content."
}

# Where the plugin writes this artifact. Empty uses the node artifact_dir.
variable "base_dir" {
  type        = string
  default     = ""
  description = "Filesystem path for this artifact. Empty to use the node artifact_dir."
}

locals {
  # Read off the parent volid, given by the node file as
  # <storage>:vztmpl/<file>. The regex is also the shape check: anything else
  # fails here, loudly, instead of producing a wrong artifact name.
  base_parent_file    = regex("^[^:]+:vztmpl/([^/]+)$", var.parent_template)[0]
  base_parent_prefix  = regex("^([^/_]+)_[0-9]+\\.[0-9]+-[0-9]+_", local.base_parent_file)[0]
  base_parent_release = regex("_([0-9]+\\.[0-9]+)-[0-9]+_", local.base_parent_file)[0]

  base_prefix = "${local.base_parent_prefix}-base"

  base_artifact = "${local.base_prefix}_${local.base_parent_release}-${var.base_build}_${var.arch}"
}

source "proxmox-lxc" "base" {
  ssh_host     = var.pve_ssh_host
  ssh_user     = var.pve_ssh_user
  ssh_password = var.pve_ssh_password
  ssh_key_path = var.pve_ssh_key_path

  # A random root password, because the plugin would otherwise leave its
  # known default on a container that runs sshd on the bridge while it's
  # provisioned. 90-finalize.sh locks the account before the artifact is made.
  root_password = uuidv4()

  template     = var.parent_template
  storage      = var.ct_storage
  bridge       = var.ct_bridge
  memory       = 2048
  cores        = 2
  rootfs_size  = "8"
  unprivileged = true
  # Modern systemd containers boot degraded without nesting.
  features = "nesting=1,keyctl=1"

  # A vzdump archive lands in the template storage: a named, versioned
  # artifact that Terraform can instantiate and that the next image pins as
  # its parent. No CTID is reserved, and nothing is overwritten as long as
  # the build number moves.
  backup_method      = "vzdump"
  backup_compression = "zstd"
  backup_name        = local.base_artifact
  backup_dir         = coalesce(var.base_dir, var.artifact_dir)
}

build {
  sources = ["source.proxmox-lxc.base"]

  provisioner "shell" {
    scripts = [
      "${path.root}/../_common/10-base.sh",
      "${path.root}/../_common/90-finalize.sh",
    ]
  }

  # Build record. The artifact lives on the node, so the manifest records no
  # local size.
  post-processor "manifest" {
    output     = "manifests/base.json"
    strip_path = true
    custom_data = {
      version = local.base_artifact
      parent  = var.parent_template
    }
  }
}
