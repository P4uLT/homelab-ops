# Node facts and image pins of this root. The shared lxc module owns
# none of them: a second PVE node can differ on every line here.

locals {
  node    = "jarvis"
  storage = "local-lvm"
  bridge  = "vmbr0"

  # Image pins, one per Packer chain image. Bump here when Packer bumps
  # the build number.
  images = {
    base   = "NAS:vztmpl/debian-13-standard-base_13.6-1_amd64.tar.zst"
    docker = "NAS:vztmpl/debian-13-standard-base-docker_13.6-1_amd64.tar.zst"
  }
}
