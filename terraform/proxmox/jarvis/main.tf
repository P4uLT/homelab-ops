# The PVE workloads of this node. One entry in the workloads map per
# container, from a Packer golden image, so the chain stays end to end: Packer
# builds the archive, Terraform clones it, Ansible configures the clone.
#
# The map lives in the git-ignored tfvars, keyed by hostname, so this file
# never names a workload: adding one is an entry there and nothing else. Each
# entry carries the volid of the Packer chain it clones.

# vmid space: 1000+ are Terraform-managed LXC workloads.

module "workload" {
  source   = "../modules/lxc"
  for_each = var.lxc_workloads

  id       = each.value.id
  hostname = each.key
  template = each.value.template

  # The node facts stay here: every entry shares them.
  node    = local.node
  storage = local.storage
  bridge  = local.bridge

  # The rest comes from the entry. A field the entry leaves out keeps the
  # default in this variable's type, which mirrors the module.
  description    = each.value.description
  tags           = each.value.tags
  protection     = each.value.protection
  os_type        = each.value.os_type
  disk           = each.value.disk
  mountpoints    = each.value.mountpoints
  cpu            = each.value.cpu
  ram            = each.value.ram
  swap           = each.value.swap
  interface_name = each.value.interface_name
  vlan_id        = each.value.vlan_id
  mac_address    = each.value.mac_address
  ipv4           = each.value.ipv4
  started        = each.value.started
  start_on_boot  = each.value.start_on_boot
  console_type   = each.value.console_type
  startup        = each.value.startup
  unprivileged   = each.value.unprivileged
  nesting        = each.value.nesting
  keyctl         = each.value.keyctl
  wait_for_ipv4  = each.value.wait_for_ipv4
}
