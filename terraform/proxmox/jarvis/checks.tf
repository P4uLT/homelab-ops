# Plan-time checks of the node facts this root relies on. The data
# sources read the node; the terraform_data resource turns a failed
# assumption into a hard plan error (a check block would only warn).
#
# Required datastores come from the root disk, LXC templates, and managed or
# referenced VM images. No second storage map is needed.

data "proxmox_datastores" "node" {
  node_name = local.node
}

data "proxmox_version" "node" {}

locals {
  # The stores this root addresses: the root disk, each LXC template, and each
  # referenced VM image.
  required_datastores = distinct(concat(
    [local.storage],
    [for workload in var.lxc_workloads : element(split(":", workload.template), 0)],
    [for image in values(local.referenced_vm_images) : image.storage],
  ))
}

resource "terraform_data" "assertions" {
  lifecycle {
    precondition {
      condition = alltrue([
        for id in local.required_datastores :
        anytrue([
          for ds in data.proxmox_datastores.node.datastores :
          ds.id == id && ds.active
        ])
      ])
      error_message = "A required datastore is missing or inactive on the node: ${join(", ", local.required_datastores)}."
    }

    precondition {
      condition     = tonumber(element(split(".", data.proxmox_version.node.release), 0)) >= 8
      error_message = "The node runs PVE ${data.proxmox_version.node.release}; this root is validated on PVE 8 or newer."
    }

    precondition {
      condition = alltrue([
        for workload in values(var.vm_workloads) :
        contains(keys(var.vm_image_downloads), workload.image) !=
        contains(keys(var.vm_image_files), workload.image)
      ])
      error_message = "Every VM workload must reference exactly one managed download or external image label."
    }

    precondition {
      condition     = length(setintersection(toset(keys(var.vm_image_downloads)), toset(keys(var.vm_image_files)))) == 0
      error_message = "An image label can't be both Terraform-managed and externally managed."
    }

    precondition {
      condition     = length(distinct(local.managed_workload_ids)) == length(local.managed_workload_ids)
      error_message = "LXC and VM workload IDs must be unique across this node."
    }

    precondition {
      condition = alltrue([
        for name in keys(var.vm_workloads) : !contains(keys(var.lxc_workloads), name)
      ])
      error_message = "LXC and VM workload names must be unique across this node."
    }

    precondition {
      condition = alltrue([
        for image in values(local.referenced_vm_images) :
        anytrue([
          for ds in data.proxmox_datastores.node.datastores :
          ds.id == image.storage && contains(ds.content_types, "iso")
        ])
      ])
      error_message = "Every referenced VM image datastore must allow ISO content."
    }

    precondition {
      condition     = length(var.vm_workloads) == 0 || var.pve_ssh_username != null
      error_message = "VM disk import requires pve_ssh_username and a loaded ssh-agent key."
    }

    precondition {
      condition     = length(distinct([for image in values(local.referenced_vm_images) : "${image.storage}/${image.file_name}"])) == length(local.referenced_vm_images)
      error_message = "Image labels must use distinct datastore filenames."
    }

    precondition {
      condition = alltrue([
        for label, image in local.external_vm_images :
        contains(keys(local.existing_vm_image_file_ids), label)
      ])
      error_message = "An external VM image file is missing from its datastore."
    }
  }
}
