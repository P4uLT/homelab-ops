locals {
  parent_volume = "${var.artifact_storage}:vztmpl/${var.parent_archive}"
  artifact_name = "homelab-${var.image_id}-lxc_${var.build_id}_${var.arch}.tar.zst"

  ansible_image_conn = "-e ansible_host=${var.pve_ssh_host} -e ansible_user=${var.pve_ssh_user} -e ansible_private_key_file=${var.pve_ssh_key_path}"

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
