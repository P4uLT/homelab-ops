output "ct_id" {
  description = "Container ID on the node."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "ct_ipv4" {
  description = "IPv4 address of eth0, from DHCP."
  value       = proxmox_virtual_environment_container.this.ipv4["eth0"]
}
