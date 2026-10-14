output "vm_id" {
  description = "VM ID on the node."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ipv4_addresses" {
  description = "Addresses reported by the guest agent, grouped by interface."
  value       = proxmox_virtual_environment_vm.this.ipv4_addresses
  sensitive   = true
}
