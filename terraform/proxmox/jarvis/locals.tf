# Node facts of this root. The shared lxc module owns none of them: a second
# PVE node can differ on every line here.
#
# LXC workloads and VM image pins live in the git-ignored tfvars.
# They're node-specific inputs, not tracked node facts.

locals {
  node    = "jarvis"
  storage = "local-lvm"
  bridge  = "vmbr0"

  # Keep source-image pins independent of workload references.
  download_vm_images   = var.vm_image_downloads
  referenced_vm_images = local.download_vm_images
}
