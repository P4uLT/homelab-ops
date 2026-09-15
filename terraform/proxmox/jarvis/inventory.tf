# The Ansible side of this root. An apply writes the inventory fragment that
# makes each workload a fleet host: its group, its name, and its container id.
# No address enters the file, because an address is a secret and lives in the
# group's secrets.sops.yaml.
#
# One file per node: a shared file would be rewritten by whichever root
# applied last, and the other node's workloads would disappear from it.
# Procedure: docs/runbooks/provision-pve-ct.md.

resource "local_file" "ansible_inventory" {
  filename = abspath("${path.root}/../../../ansible/inventory/servers/iac.tf.${local.node}.yml")

  file_permission = "0644"

  content = templatefile("${path.module}/templates/ansible-inventory.yml.tftpl", {
    node      = local.node
    workloads = var.lxc_workloads
  })
}
