build {
  sources = ["source.proxmox-lxc.image"]

  provisioner "shell-local" {
    inline = [
      "task -d ${path.root}/../../.. ansible:image -- --limit ${var.ansible_limit} ${local.ansible_image_conn} -e proxmox_vmid=${var.build_ctid} -e image_finalize_name=${var.image_id} -e image_finalize_version=${var.build_id} -e image_finalize_parent=${local.parent_volume}",
    ]
  }

  post-processor "manifest" {
    output      = var.manifest_path
    strip_path  = true
    custom_data = local.manifest_custom_data
  }
}
