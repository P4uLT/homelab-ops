# Node facts of this root. The shared lxc module owns none of them: a second
# PVE node can differ on every line here.
#
# LXC and VM workloads and pinned image downloads live in the git-ignored
# tfvars. They're node-specific inputs, not tracked node facts.

locals {
  node    = "jarvis"
  storage = "local-lvm"
  bridge  = "vmbr0"

  # Only external, datasource-only lookups are scoped to workload references.
  # An unreferenced external file stays unmanaged.
  referenced_vm_image_labels = toset([
    for workload in values(var.vm_workloads) : workload.image
  ])

  # Keep downloads independent from workloads. Removing a workload must not
  # delete its reusable pinned image.
  download_vm_images = var.vm_image_downloads

  # A managed download's file ID is deterministic. Its resource ID is unknown
  # while recreating the source, which would otherwise force VM replacement.
  download_vm_image_file_ids = {
    for label, image in local.download_vm_images :
    label => "${image.storage}:iso/${image.file_name}"
  }

  external_vm_images = {
    for label, image in var.vm_image_files : label => image
    if contains(local.referenced_vm_image_labels, label)
  }
  referenced_vm_images = merge(
    { for label, image in local.download_vm_images : label => image },
    { for label, image in local.external_vm_images : label => image },
  )
  valid_vm_workloads = {
    for name, workload in var.vm_workloads : name => workload
    if contains(keys(local.download_vm_images), workload.image) ||
    (contains(keys(local.external_vm_images), workload.image) &&
    contains(keys(local.existing_vm_image_file_ids), workload.image))
  }

  managed_workload_ids = concat(
    [for workload in values(var.lxc_workloads) : workload.id],
    [for workload in values(var.vm_workloads) : workload.id],
  )
}
