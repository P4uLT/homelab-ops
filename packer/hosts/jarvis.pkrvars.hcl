# Facts of the PVE node jarvis. Everything here is public: the address and
# the login live in jarvis.local.pkrvars.hcl, which Git ignores.
#
# jarvis reads the parent and writes artifacts on the shared NAS.

artifact_storage = "NAS"
artifact_dir     = "/mnt/pve/NAS/template/cache"

ct_storage = "local-lvm"
ct_bridge  = "vmbr0"
