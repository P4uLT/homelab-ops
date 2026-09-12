variable "node" {
  description = "PVE node that runs the container."
  type        = string
}

variable "id" {
  description = "Container ID on the node. Unique across the node."
  type        = number
}

variable "hostname" {
  description = "Container hostname. Also its name in the node UI."
  type        = string
}

variable "template" {
  description = "Golden image the container instantiates, as a full volid. Example: NAS:vztmpl/debian-13-standard-base-docker_13.6-1_amd64.tar.zst."
  type        = string
}

variable "storage" {
  description = "Storage that holds the root disk. A node fact: the calling root supplies it."
  type        = string
}

variable "disk" {
  description = "Root disk size, in gibibytes."
  type        = number
  default     = 8
}

variable "bridge" {
  description = "Network bridge of the container. A node fact: the calling root supplies it."
  type        = string
}

variable "os_type" {
  description = "PVE operating system type of the golden image. The Packer chain builds Debian."
  type        = string
  default     = "debian"
}

variable "cpu" {
  description = "Number of assigned CPU cores."
  type        = number
  default     = 1
}

variable "ram" {
  description = "Dedicated memory, in mebibytes."
  type        = number
  default     = 1024
}

variable "unprivileged" {
  description = "Run the container without root privileges on the node."
  type        = bool
  default     = true
}

variable "started" {
  description = "Start the container after creation."
  type        = bool
  default     = true
}

variable "nesting" {
  description = "PVE nesting feature. Containers that run containers need it."
  type        = bool
  default     = false
}

variable "keyctl" {
  description = "PVE keyctl feature. Docker in an unprivileged container needs it."
  type        = bool
  default     = false
}

variable "tags" {
  description = "PVE tags of the container."
  type        = list(string)
  default     = ["terraform"]
}
