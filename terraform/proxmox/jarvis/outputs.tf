# One entry per workload in the map, keyed by hostname.
output "lxcs" {
  description = "The LXC workloads by name: container ID and IPv4. One entry per workload."
  sensitive   = true
  value = {
    for name, workload in module.workload :
    name => {
      ct_id   = workload.ct_id
      ct_ipv4 = workload.ct_ipv4
    }
  }
}

output "vms" {
  description = "The VM workloads by name: VM ID and guest-reported IPv4 addresses."
  sensitive   = true
  value = {
    for name, workload in module.vm :
    name => {
      vm_id          = workload.vm_id
      ipv4_addresses = workload.ipv4_addresses
    }
  }
}
