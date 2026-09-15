# Shared technical layer: the plugin, and the variables every image uses.
# One image is one file in this directory, holding everything about it:
# version, parent, resources, and scripts.

packer {
  required_plugins {
    proxmox-lxc = {
      # Exact on purpose. Packer has no lockfile, so a range would adopt any
      # future 0.1.x at the next init on a fresh machine. The plugin runs
      # beside the repository secrets, so a version bump is a deliberate act.
      version = "0.1.5"
      source  = "github.com/leoarry/proxmox-lxc"
    }
  }
}

# The node address and login live in the git-ignored per-node file
# packer/hosts/<node>.local.pkrvars.hcl, never in the repository. The plugin
# drives pct over SSH and never touches the PVE API, so no API token is
# involved. Neither is sensitive: marking an address sensitive makes Packer
# redact every occurrence of its text in the output, and the plugin prints
# the address anyway.
variable "pve_ssh_host" {
  type        = string
  description = "SSH address of the PVE node, from the node local var file."
}

variable "pve_ssh_user" {
  type        = string
  description = "SSH login on the PVE node. A real Linux login, not user@realm."
}

# The plugin takes the password when both are set, so leave it empty and give
# a key instead.
variable "pve_ssh_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Password of the node login. Prefer a key: the plugin connects without checking the host key."
}

variable "pve_ssh_key_path" {
  type        = string
  default     = ""
  description = "Absolute path to a passphrase-less private key. The plugin reads the file directly, so it expands neither ~ nor a prompt."
}

variable "arch" {
  type        = string
  default     = "amd64"
  description = "Artifact architecture, as the pveam names carry it."
}

# The chain defaults, overridable per node in hosts/<node>.pkrvars.hcl.
# Reading the parent and writing our artifacts are two different things: the
# parent volid carries its own storage, the artifacts go to theirs.
variable "parent_template" {
  type        = string
  default     = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  description = "Volid of the official container template the first image builds on."
}

variable "artifact_storage" {
  type        = string
  default     = "local"
  description = "Storage our artifacts are written to and addressed from, so a child image finds its parent there. Overridable per node, then per image."
}

variable "artifact_dir" {
  type        = string
  default     = "/var/lib/vz/template/cache"
  description = "Filesystem path the plugin writes artifacts to. PVE mounts a vztmpl storage at /mnt/pve/<id>, templates in template/cache. Overridable per node, then per image."
}

variable "ct_storage" {
  type        = string
  description = "Node storage for the container root filesystem."
}

variable "ct_bridge" {
  type        = string
  description = "Node network bridge for the build container."
}

# What every image playbook needs to reach its build container. The facts come
# from the same git-ignored per-node local var file the plugin reads, so the
# key path is never duplicated, and the container id stays per image. The
# interpreter is a static fact and lives in the image inventory instead.
locals {
  ansible_image_conn = "-e ansible_host=${var.pve_ssh_host} -e ansible_user=${var.pve_ssh_user} -e ansible_private_key_file=${var.pve_ssh_key_path}"
}
