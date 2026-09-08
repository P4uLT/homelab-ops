# packer/

This directory will contain golden LXC images for Proxmox VE. Packer builds
the images, and a later phase adds digest locking. Cattle containers come
from these images. Never patch a cattle container in place. The directory
stays a placeholder until that phase.
