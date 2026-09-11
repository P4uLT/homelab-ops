# Facts of the PVE node jarvis. Everything here is public: the address and
# the login live in jarvis.local.pkrvars.hcl, which Git ignores.
#
# Everything set here overrides the global defaults of images/base.pkr.hcl.
# jarvis reads the official template from the NFS share and writes the
# artifacts there too, so every node sees the same artifacts.

parent_template  = "NAS:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
artifact_storage = "NAS"
artifact_dir     = "/mnt/pve/NAS/template/cache"

ct_storage = "local-lvm"
ct_bridge  = "vmbr0"
