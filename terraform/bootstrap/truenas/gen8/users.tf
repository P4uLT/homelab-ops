resource "truenas_group" "managed" {
  for_each = var.groups

  name = each.value.name
  gid  = each.value.gid
  smb  = each.value.smb
}

resource "truenas_user" "managed" {
  for_each = var.users

  username             = each.value.username
  full_name            = each.value.full_name
  uid                  = each.value.uid
  email                = each.value.email
  home                 = each.value.home
  home_mode            = each.value.home_mode
  shell                = each.value.shell
  smb                  = each.value.smb
  locked               = each.value.locked
  ssh_password_enabled = each.value.ssh_password_enabled
  sshpubkey            = each.value.sshpubkey
  group                = truenas_group.managed[each.value.primary_group].id
  group_create         = false
  groups               = [for group in each.value.additional_groups : truenas_group.managed[group].id]
  password_disabled    = !each.value.smb && !each.value.ssh_password_enabled
  password             = lookup(var.user_passwords, each.key, null)
  password_wo_version  = each.value.password_wo_version
}
