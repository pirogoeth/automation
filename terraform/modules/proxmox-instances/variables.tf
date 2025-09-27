variable "proxmox_node" {
  description = "Proxmox node to create VMs on."
  type        = string
}

variable "authorized_keys_file" {
  description = "Path to file containing public SSH keys for remoting into nodes."
  type        = string
}

variable "instance_prefix" {
  description = "Prefix to use for node names"
  type        = string
}

variable "proxmox_resource_pool" {
  description = "Resource pool name to use in proxmox to better organize nodes."
  type        = string
  default     = ""
}

variable "source_template" {
  description = "Name of the template to clone from."
  type        = string
}

variable "shape" {
  type = object({
    cores            = optional(number, 2),
    sockets          = optional(number, 1),
    memory           = optional(number, 4096),
    memory_balloon   = optional(number),
    storage_type     = optional(string, "scsi"),
    storage_id       = optional(string, "local-lvm"),
    disk_size        = optional(string, "10G"),
    root_disk_backup = optional(bool, false),
    extra_disks = optional(list(object({
      size    = string,
      storage = optional(string, "local-lvm"),
      type    = optional(string, "virtio"),
      cache   = optional(string, "none"),
      backup  = optional(bool, false),
    })), []),
    user           = optional(string, "k3s"),
    network_bridge = optional(string, "vmbr0"),
    network_tag    = optional(number, -1),
  })
}

variable "instance_count" {
  description = "Number of instances."
  default     = 2
  type        = number
}

variable "nameserver" {
  default     = ""
  type        = string
  description = "nameserver"
}

variable "domain_name" {
  description = "Domain base to use for node hostnames"
  type        = string
  default     = "k3s.local"
}

variable "network_gateway" {
  description = "Gateway to use for nodes"
  type        = string
  default     = null
}

variable "subnet" {
  description = "Subnet to use for nodes"
  type        = string
  default     = null
}

variable "startup_options" {
  description = "Additional startup options to pass to Proxmox"
  type        = string
  default     = ""
}

variable "attributes" {
  description = "Additional attributes to add to the instance's inventory"
  type        = map(any)
  default     = {}
}
