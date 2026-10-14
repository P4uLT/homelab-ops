# One imported-image VM per map entry. VM workloads stay outside the LXC
# inventory.
module "vm" {
  source   = "../modules/vm"
  for_each = local.valid_vm_workloads

  id   = each.value.id
  name = each.key
  image_file_id = contains(keys(local.download_vm_images), each.value.image) ? (
    local.download_vm_image_file_ids[each.value.image]
  ) : local.existing_vm_image_file_ids[each.value.image]

  node    = local.node
  storage = local.storage
  bridge  = local.bridge

  cpu              = each.value.cpu
  ram              = each.value.ram
  disk             = each.value.disk
  description      = each.value.description
  tags             = each.value.tags
  vlan_id          = each.value.vlan_id
  mac_address      = each.value.mac_address
  started          = each.value.started
  start_on_boot    = each.value.start_on_boot
  startup          = each.value.startup
  additional_disks = each.value.additional_disks

  depends_on = [
    terraform_data.assertions,
    proxmox_download_file.vm_image,
  ]
}
