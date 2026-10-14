# Terraform-managed PVE access objects for Jarvis.

provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token

  # PVE ships a self-signed certificate.
  insecure = true
}

resource "proxmox_virtual_environment_role" "terraform_provisioning" {
  role_id = "Terraform_Provisioning"

  # Workload privileges for LXC templates, VM images, and SDN bridges.
  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
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

  # Token-only: this root declares no password. Retire the legacy password on
  # the node after the first apply. See the runbook.
  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_acl" "terraform_provisioning" {
  path      = "/"
  role_id   = proxmox_virtual_environment_role.terraform_provisioning.role_id
  group_id  = proxmox_virtual_environment_group.terraform_provisioning.group_id
  propagate = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_user_token" "tf" {
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
  to = proxmox_acl.terraform_provisioning
  id = "/?Terraform_Provisioning?Terraform_Provisioning"
}
