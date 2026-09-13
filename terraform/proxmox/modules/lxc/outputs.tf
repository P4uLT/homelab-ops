output "ct_id" {
  description = "Container ID on the node."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "ct_ipv4" {
  description = "IPv4 address of the container interface, from DHCP. Null until the guest reports a lease on that interface."
  value       = try(proxmox_virtual_environment_container.this.ipv4[var.interface_name], null)
}
