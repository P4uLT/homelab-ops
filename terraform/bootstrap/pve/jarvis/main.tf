# The Terraform access chain of the node jarvis: role, group, user,
# ACL, API token. Run-once and frozen: every resource carries
# prevent_destroy, and a change here is a reviewed commit. The root
# authenticates as the minting account (root@pam by default), the only
# credential that can mint the token the workload roots use. Ansible no
# longer declares any of these objects.
#
# The import blocks adopt, one time, the objects the Ansible plane
# created before this root existed. After the first apply they're
# no-ops and stay as provenance.

provider "proxmox" {
  endpoint = var.pve_endpoint
  username = var.pve_username
  password = var.pve_password

  # PVE ships a self-signed certificate.
  insecure = true
}

resource "proxmox_virtual_environment_role" "terraform_provisioning" {
  role_id = "Terraform_Provisioning"

  # The lean operational set for unprivileged LXC workloads from the
  # template storages, plus the full VM.Config.* set PVE defines (mount
  # points need nothing beyond it) and SDN.Use, checked when a NIC
  # attaches to a bridge inside an SDN zone. A missing privilege fails
  # with 403, and the PVE log names it. An unknown one fails with 400,
  # and PVE rejects the whole role: check the API list before adding
  # one.
  privileges = [
    "Datastore.AllocateSpace",
    "Datastore.Audit",
    "Pool.Allocate",
    "SDN.Use",
    "Sys.Audit",
    "Sys.Console",
    "Sys.Modify",
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.Cloudinit",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Migrate",
    "VM.PowerMgmt",
  ]

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_group" "terraform_provisioning" {
  group_id = "Terraform_Provisioning"

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_user" "terraform_prov" {
  user_id = "terraform-prov@pve"
  enabled = true
  groups  = [proxmox_virtual_environment_group.terraform_provisioning.group_id]

  # Token-only: no password is declared here. The Ansible-era password
  # is retired once, on the node, after the first apply. See the
  # runbook.
  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_acl" "terraform_provisioning" {
  path      = "/"
  role_id   = proxmox_virtual_environment_role.terraform_provisioning.role_id
  group_id  = proxmox_virtual_environment_group.terraform_provisioning.group_id
  propagate = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_user_token" "tf" {
  user_id    = proxmox_virtual_environment_user.terraform_prov.user_id
  token_name = "tf"

  # No privilege separation: the token inherits the user, which sits in
  # the group, which holds the ACL. One chain to audit.
  privileges_separation = false

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = proxmox_virtual_environment_role.terraform_provisioning
  id = "Terraform_Provisioning"
}

import {
  to = proxmox_virtual_environment_group.terraform_provisioning
  id = "Terraform_Provisioning"
}

import {
  to = proxmox_virtual_environment_user.terraform_prov
  id = "terraform-prov@pve"
}

import {
  to = proxmox_virtual_environment_acl.terraform_provisioning
  id = "/?Terraform_Provisioning?Terraform_Provisioning"
}
