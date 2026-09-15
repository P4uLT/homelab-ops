# Docker Engine on the base. The parent is pinned by file name, so this
# image builds alone, whenever it wants, on the base build it declares.
# Bump the pin deliberately: it decides which base this image carries.

variable "docker_build" {
  type        = number
  default     = 1
  description = "Build number. Bump it when the image content changes, never to rebuild the same content."
}

# Where the plugin writes this artifact. Empty uses the node artifact_dir.
variable "docker_dir" {
  type        = string
  default     = ""
  description = "Filesystem path for this artifact. Empty to use the node artifact_dir."
}

# The build container's id, pinned so the playbook knows where to enter and so
# Packer can resume a failed build on the same container. A string, because
# that's the type the plugin declares for `ctid`. Overridable per node in
# hosts/<node>.pkrvars.hcl.
variable "docker_ctid" {
  type        = string
  default     = "901"
  description = "Pinned CTID of the build container."
}

# The pin is the artifact file name, not a volid: the artifact is a content
# decision, the storage holding it comes from a node fact (artifact_storage).
variable "docker_parent" {
  type        = string
  default     = "debian-13-standard-base_13.6-1_amd64.tar.zst"
  description = "Artifact this image builds on. A build fails here on a name the node storage doesn't have."
}

locals {
  # Same rule as every image: the chain is read off the parent.
  # Both regexes also assert the shape of the pin: a bare file name whose
  # release reads <major>.<minor>-<build>. Anything else fails here, loudly.
  docker_parent_prefix  = regex("^([^/_]+)_[0-9]+\\.[0-9]+-[0-9]+_", var.docker_parent)[0]
  docker_parent_release = regex("_([0-9]+\\.[0-9]+)-[0-9]+_", var.docker_parent)[0]

  docker_prefix = "${local.docker_parent_prefix}-docker"

  docker_artifact = "${local.docker_prefix}_${local.docker_parent_release}-${var.docker_build}_${var.arch}"

  docker_parent_volid = "${var.artifact_storage}:vztmpl/${var.docker_parent}"
}

source "proxmox-lxc" "docker" {
  ssh_host     = var.pve_ssh_host
  ssh_user     = var.pve_ssh_user
  ssh_password = var.pve_ssh_password
  ssh_key_path = var.pve_ssh_key_path

  # A random root password, because the plugin would otherwise leave its
  # known default on a container that runs sshd on the bridge while it's
  # provisioned. The image_finalize role locks the account before the artifact
  # is made.
  root_password = uuidv4()

  # The pinned container the playbook enters. Without this line the plugin
  # auto-assigns an id and the two sides disagree: the build provisions nothing
  # and looks successful.
  ctid = var.docker_ctid

  template    = local.docker_parent_volid
  storage     = var.ct_storage
  bridge      = var.ct_bridge
  memory      = 4096
  cores       = 2
  rootfs_size = "16"
  # Docker needs nesting; keyctl covers secrets and keyrings inside
  # unprivileged containers.
  features     = "nesting=1,keyctl=1"
  unprivileged = true

  backup_method      = "vzdump"
  backup_compression = "zstd"
  backup_name        = local.docker_artifact
  backup_dir         = coalesce(var.docker_dir, var.artifact_dir)
}

build {
  sources = ["source.proxmox-lxc.docker"]

  # Same as base.pkr.hcl: the task owns the provisioning, the inventory and
  # --limit pick the image, and the connection comes from the node local file.
  provisioner "shell-local" {
    inline = [
      "task -d ${path.root}/../.. ansible:image -- --limit builder-docker ${local.ansible_image_conn} -e proxmox_vmid=${var.docker_ctid} -e image_name=docker -e image_version=${local.docker_artifact} -e image_parent=${local.docker_parent_volid}",
    ]
  }

  post-processor "manifest" {
    output     = "manifests/docker.json"
    strip_path = true
    custom_data = {
      version = local.docker_artifact
      parent  = local.docker_parent_volid
    }
  }
}
