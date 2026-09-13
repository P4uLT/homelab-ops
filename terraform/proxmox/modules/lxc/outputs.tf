output "ct_id" {
  description = "Container ID on the node."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "ct_ipv4" {
  description = "IPv4 address of the container interface."
  value       = proxmox_virtual_environment_container.this.ipv4[var.interface_name]
}
