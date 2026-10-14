source "proxmox-lxc" "image" {
  ssh_host           = var.pve_ssh_host
  ssh_user           = var.pve_ssh_user
  ssh_password       = var.pve_ssh_password
  ssh_key_path       = var.pve_ssh_key_path
  ssh_key_passphrase = var.pve_ssh_key_passphrase
  ssh_agent_auth     = var.pve_ssh_agent_auth

  root_password = uuidv4()
  ctid          = var.build_ctid
  template      = local.parent_volume
  storage       = var.ct_storage
  bridge        = var.ct_bridge
  memory        = var.ct_memory
  cores         = var.ct_cores
  rootfs_size   = var.ct_rootfs_size
  unprivileged  = true
  features      = "nesting=1,keyctl=1"

  backup_method      = "vzdump"
  backup_compression = "zstd"
  backup_name        = trimsuffix(local.artifact_name, ".tar.zst")
  backup_dir         = var.artifact_dir
}
