output "lxcs" {
  description = "The LXC workloads by name: container ID and IPv4, from DHCP. One entry per module call."
  value = {
    tf-test = {
      ct_id   = module.tf_test.ct_id
      ct_ipv4 = module.tf_test.ct_ipv4
    }
  }
}
