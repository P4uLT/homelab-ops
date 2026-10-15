locals {
  repository_root = abspath("${path.root}/../../..")
  parent_volume   = "${var.artifact_storage}:vztmpl/${var.parent_archive}"
  artifact_name   = "homelab-${var.image_id}-lxc_${var.build_id}_${var.arch}.tar.zst"

  manifest_custom_data = {
    image_id        = var.image_id
    image_kind      = var.image_kind
    os_id           = var.os_id
    os_major        = var.os_major
    arch            = var.arch
    build_id        = var.build_id
    parent_archive  = var.parent_archive
    source_revision = var.source_revision
    plugin_source   = "github.com/leoarry/proxmox-lxc"
    plugin_version  = "0.1.5"
  }
}
