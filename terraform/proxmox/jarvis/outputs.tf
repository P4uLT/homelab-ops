# Mirror of main.tf: one entry per module call, same order, keyed by
# hostname.
output "lxcs" {
  description = "The LXC workloads by name: container ID and IPv4. One entry per module call."
  value = {
    tf-test = {
      ct_id   = module.tf_test.ct_id
      ct_ipv4 = module.tf_test.ct_ipv4
    }
  }
}
