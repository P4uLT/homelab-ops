# Node facts of this root. The shared lxc module owns none of them: a second
# PVE node can differ on every line here.
#
# The workloads, and the image each one clones, live in the git-ignored tfvars
# instead: they're per-container, and their addresses aren't for a tracked
# file.

locals {
  node    = "jarvis"
  storage = "local-lvm"
  bridge  = "vmbr0"
}
