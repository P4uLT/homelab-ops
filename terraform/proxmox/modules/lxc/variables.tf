variable "node" {
  description = "PVE node that runs the container."
  type        = string
}

variable "id" {
  description = "Container ID on the node. Unique across the node."
  type        = number

  validation {
    condition     = var.id >= 100 && var.id <= 999999999
    error_message = "id must sit in the PVE VMID range 100-999999999."
  }
}

variable "hostname" {
  description = "Container hostname. Also its name in the node UI."
  type        = string
}

variable "description" {
  description = "Provenance note shown in the node UI."
  type        = string
  default     = "Managed by Terraform (homelab-ops)"
}

variable "tags" {
  description = "PVE tags of the container. PVE lowercases every tag."
  type        = list(string)
  default     = ["terraform"]
}

variable "protection" {
  description = "PVE protection flag. A protected container refuses deletion on the node, so a destroy stays a deliberate two-step: lift the flag first."
  type        = bool
  default     = false
}

variable "template" {
  description = "Golden image the container instantiates, as a full volid. Example: NAS:vztmpl/debian-13-standard-base-docker_13.6-1_amd64.tar.zst."
  type        = string
}

variable "os_type" {
  description = "PVE operating system type of the golden image. The Packer chain builds Debian."
  type        = string
  default     = "debian"

  validation {
    condition = contains(
      ["alpine", "archlinux", "centos", "debian", "devuan", "fedora", "gentoo", "nixos", "opensuse", "ubuntu", "unmanaged"],
      var.os_type
    )
    error_message = "os_type must be a PVE container OS type."
  }
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

variable "mountpoints" {
  description = "Extra mount points. volume is a host path, device, or directory; path is where the container mounts it."
  type = list(object({
    volume    = string
    path      = string
    size      = optional(number)
    backup    = optional(bool, false)
    read_only = optional(bool, false)
  }))
  default = null
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

variable "swap" {
  description = "Swap memory, in mebibytes."
  type        = number
  default     = 512
}

variable "interface_name" {
  description = "Name of the network interface inside the container."
  type        = string
  default     = "eth0"
}

variable "bridge" {
  description = "Network bridge of the container. A node fact: the calling root supplies it."
  type        = string
}

variable "vlan_id" {
  description = "VLAN tag of the interface. Null keeps the bridge default."
  type        = number
  default     = null
}

variable "mac_address" {
  description = "Stable MAC address. A stable value enables a DHCP reservation; null lets the node generate one."
  type        = string
  default     = null
}

variable "ipv4" {
  description = "IPv4 of the interface. The default holds \"dhcp\"; a static value may only come from a git-ignored tfvars, never a tracked file."
  type = object({
    address = optional(string, "dhcp")
    gateway = optional(string)
  })
  default = { address = "dhcp" }
}

variable "started" {
  description = "Start the container after creation."
  type        = bool
  default     = true
}

variable "start_on_boot" {
  description = "Start the container when the node boots."
  type        = bool
  default     = true
}

variable "startup" {
  description = "Boot order and delays, when the boot order matters. Null uses the node defaults."
  type = object({
    order      = number
    up_delay   = optional(number)
    down_delay = optional(number)
  })
  default = null
}

variable "console_type" {
  description = "Console mode. Shell invokes a shell inside the container without a login, so an account without a password still has a console. PVE names this setting cmode."
  type        = string
  default     = "shell"

  validation {
    condition     = contains(["console", "shell", "tty"], var.console_type)
    error_message = "console_type must be console, shell, or tty."
  }
}

variable "unprivileged" {
  description = "Run the container without root privileges on the node."
  type        = bool
  default     = true
}

variable "nesting" {
  description = "PVE nesting feature. Containers that run containers need it."
  type        = bool
  default     = false
}

variable "keyctl" {
  description = "PVE keyctl feature. PVE lets only the real root@pam login change feature flags other than nesting: a token-authenticated root gets a 403 at create. Leave false unless the root authenticates as root@pam."
  type        = bool
  default     = false
}

variable "wait_for_ipv4" {
  description = "Make apply wait for a non-loopback IPv4 after start, so ct_ipv4 is usable right away. Turn off when no DHCP server answers the bridge."
  type        = bool
  default     = true
}
