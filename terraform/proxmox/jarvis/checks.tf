# Plan-time checks of the node facts this root relies on. The data
# sources read the node; the terraform_data resource turns a failed
# assumption into a hard plan error (a check block would only warn).
#
# Required datastores come from the root disk, LXC templates, and managed VM
# images. No second storage map is needed.

data "proxmox_datastores" "node" {
  node_name = local.node
}

data "proxmox_version" "node" {}

locals {
  # The storages this root actually addresses: the root-disk storage, plus the
  # store named in each workload's golden-image volid ("NAS:vztmpl/...").
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
        for image in values(local.referenced_vm_images) :
        anytrue([
          for ds in data.proxmox_datastores.node.datastores :
          ds.id == image.storage && contains(ds.content_types, "iso")
        ])
      ])
      error_message = "Every referenced VM image datastore must allow ISO content."
    }

    precondition {
      condition     = length(distinct([for image in values(local.referenced_vm_images) : "${image.storage}/${image.file_name}"])) == length(local.referenced_vm_images)
      error_message = "Image labels must use distinct datastore filenames."
    }

  }
}
