# The PVE workloads of this node. One lxc module call per container,
# from a Packer golden image, so the chain stays end to end: Packer
# builds the archive, Terraform clones it, Ansible will configure the
# clone later. A new container is a new call, plus a line in outputs.tf.

# vmid space: 1000+ are Terraform-managed LXC workloads.
module "tf_test" {
  source   = "../modules/lxc"
  node     = local.node
  id       = 1000
  hostname = "tf-test"
  template = local.images.docker
  storage  = local.storage
  bridge   = local.bridge

  # Docker in an unprivileged container needs nesting and keyctl.
  nesting = true
  keyctl  = true
}
