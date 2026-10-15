build {
  sources = ["source.proxmox-lxc.image"]

  provisioner "ansible" {
    command             = "${local.repository_root}/ansible/.venv/bin/ansible-playbook"
    playbook_file       = "${local.repository_root}/ansible/playbooks/image.yml"
    inventory_directory = "${local.repository_root}/ansible/inventory/builders"
    host_alias          = var.ansible_limit
    user                = var.pve_ssh_user
    use_proxy           = false
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${local.repository_root}/ansible/ansible.cfg",
      "ANSIBLE_LOCAL_TEMP=${local.repository_root}/ansible/config/tmp",
      "ANSIBLE_LOG_PATH=${local.repository_root}/ansible/config/tmp/ansible.log",
    ]
    extra_arguments = [
      "-i", "${local.repository_root}/ansible/inventory/builders",
      "--limit", var.ansible_limit,
      "--extra-vars", jsonencode({
        ansible_host             = var.pve_ssh_host
        ansible_user             = var.pve_ssh_user
        ansible_private_key_file = var.pve_ssh_key_path
        proxmox_vmid             = var.build_ctid
        image_finalize_name      = var.image_id
        image_finalize_version   = var.build_id
        image_finalize_parent    = local.parent_volume
      }),
    ]
  }

  post-processor "manifest" {
    output      = var.manifest_path
    strip_path  = true
    custom_data = local.manifest_custom_data
  }
}
