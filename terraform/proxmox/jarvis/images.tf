# Discover existing files for managed downloads and external image references.
data "proxmox_files" "vm_images" {
  for_each = toset([for image in values(local.referenced_vm_images) : image.storage])

  node_name    = local.node
  datastore_id = each.key
  content_type = "iso"
}

locals {
  existing_vm_image_file_ids = {
    for label, image in local.referenced_vm_images :
    label => one([
      for file in data.proxmox_files.vm_images[image.storage].files : file.id
      if file.file_name == image.file_name
    ])
    if anytrue([
      for file in data.proxmox_files.vm_images[image.storage].files :
      file.file_name == image.file_name
    ])
  }

  existing_vm_images = {
    for label, file_id in local.existing_vm_image_file_ids :
    label => "${local.node}/${file_id}"
    if contains(keys(local.download_vm_images), label)
  }
}

import {
  for_each = local.existing_vm_images
  to       = proxmox_download_file.vm_image[each.key]
  id       = each.value
}

resource "proxmox_download_file" "vm_image" {
  for_each = local.download_vm_images

  node_name               = local.node
  datastore_id            = each.value.storage
  content_type            = "iso"
  url                     = each.value.url
  file_name               = each.value.file_name
  checksum                = each.value.sha256
  checksum_algorithm      = "sha256"
  decompression_algorithm = "zst"
  overwrite               = false
  overwrite_unmanaged     = false

  lifecycle {
    # Imports can't recover download metadata. Ignore pin changes so Terraform
    # doesn't replace existing image bytes.
    ignore_changes = [url, checksum, checksum_algorithm, decompression_algorithm]
  }

  depends_on = [terraform_data.assertions]
}
