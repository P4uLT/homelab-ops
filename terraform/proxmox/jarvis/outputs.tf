# One entry per workload in the map, keyed by hostname.
output "lxcs" {
  description = "The LXC workloads by name: container ID and IPv4. One entry per workload."
  value = {
    for name, workload in module.workload :
    name => {
      ct_id   = workload.ct_id
      ct_ipv4 = workload.ct_ipv4
    }
  }
}
