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

  bios                = each.value.bios
  machine             = each.value.machine
  boot_order          = each.value.boot_order
  scsi_hardware       = each.value.scsi_hardware
  hotplug             = each.value.hotplug
  reboot_after_update = each.value.reboot_after_update
  cpu                 = each.value.cpu
  memory              = each.value.memory
  disk                = each.value.disk
  agent               = each.value.agent
  efi_disk            = each.value.efi_disk
  network_devices     = each.value.network_devices
  vga                 = each.value.vga
  timeouts            = each.value.timeouts
  os_type             = each.value.os_type
  protection          = each.value.protection
  prevent_destroy     = each.value.prevent_destroy
  description         = each.value.description
  tags                = each.value.tags
  started             = each.value.started
  start_on_boot       = each.value.start_on_boot
  startup             = each.value.startup
  additional_disks    = each.value.additional_disks

  depends_on = [
    terraform_data.assertions,
    proxmox_download_file.vm_image,
  ]
}
