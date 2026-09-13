# The PVE workloads of this node. One lxc module call per container,
# from a Packer golden image, so the chain stays end to end: Packer
# builds the archive, Terraform clones it, Ansible will configure the
# clone later. A new container is a new call, plus a line in outputs.tf.
#
# Calls read top to bottom: identity, image, then the node facts of
# locals.tf, then per-container features. Calls sort by id. The image
# names a Packer chain: local.images.<chain> pins the volid in locals.tf.

# vmid space: 1000+ are Terraform-managed LXC workloads.

# tf-test: scratch container that exercises the provisioning chain.
module "tf_test" {
  source = "../modules/lxc"

  id       = 1000
  hostname = "tf-test"

  template = local.images.docker

  node    = local.node
  storage = local.storage
  bridge  = local.bridge

  # Nesting is the one feature flag an API token may set; keyctl is
  # root@pam-only in PVE. The golden image carries Docker, and the
  # local-lvm storage needs no fuse workaround.
  nesting = true
}

# <purpose>: <one line on the workload's role>.
# module "<name>" {
#   source = "../modules/lxc"
#
#   id       = 1001
#   hostname = "<name>"
#
#   template = local.images.base
#
#   node    = local.node
#   storage = local.storage
#   bridge  = local.bridge
# }
