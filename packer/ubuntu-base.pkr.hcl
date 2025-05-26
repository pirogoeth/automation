packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type    = string
  default = env("PROXMOX_URL")
}

variable "proxmox_username" {
  type    = string
  default = env("PROXMOX_USERNAME")
}

variable "proxmox_password" {
  type    = string
  default = env("PROXMOX_PASSWORD")
}

variable "proxmox_token" {
  type    = string
  default = env("PROXMOX_TOKEN")
}

variable "proxmox_node" {
  type    = string
  default = env("PROXMOX_NODE")
}

variable "skip_tls_verify" {
  type    = bool
  default = env("PROXMOX_TLS_SKIP_VERIFY")
}

variable "ubuntu_release" {
  type    = string
  default = "jammy"
}

variable "ubuntu_version_snapshot" {
  type    = string
  default = "current"
}

variable "machine_arch" {
  type    = string
  default = "amd64"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
}

variable "vm_storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "iso_checksum" {
  type    = string
  default = ""
}

variable "ssh_bastion_host" {
  type    = string
  default = ""
}

variable "ssh_bastion_port" {
  type    = string
  default = ""
}

variable "ssh_bastion_agent_auth" {
  type    = string
  default = ""
}

variable "ssh_bastion_username" {
  type    = string
  default = ""
}

variable "ssh_bastion_password" {
  type    = string
  default = ""
}

variable "ssh_bastion_interactive" {
  type    = bool
  default = false
}

variable "ssh_bastion_private_key_file" {
  type    = string
  default = ""
}

variable "ssh_bastion_certificate_file" {
  type    = string
  default = ""
}

locals {
  image_name = "${var.ubuntu_release}-server-cloudimg-${var.machine_arch}.img"
}

data "http" "image_checksum" {
  url = "https://cloud-images.ubuntu.com/${var.ubuntu_release}/${var.ubuntu_version_snapshot}/SHA256SUMS"
}

locals {
  remote_checksum_lines  = split("\n", data.http.image_checksum.body)
  remote_checksum_pairs  = [for line in local.remote_checksum_lines : split("*", line) if trimspace(line) != ""]
  remote_image_checksums = { for pair in local.remote_checksum_pairs : pair[1] => trimspace(pair[0]) }
}

source "proxmox-iso" "ubuntu" {
  communicator                 = "ssh"
  ssh_bastion_host             = var.ssh_bastion_host
  ssh_bastion_port             = var.ssh_bastion_port
  ssh_bastion_agent_auth       = var.ssh_bastion_agent_auth
  ssh_bastion_username         = var.ssh_bastion_username
  ssh_bastion_password         = var.ssh_bastion_password
  ssh_bastion_interactive      = var.ssh_bastion_interactive
  ssh_bastion_private_key_file = var.ssh_bastion_private_key_file
  ssh_bastion_certificate_file = var.ssh_bastion_certificate_file

  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.skip_tls_verify

  iso_url          = "https://cloud-images.ubuntu.com/${var.ubuntu_release}/${var.ubuntu_version_snapshot}/${local.image_name}"
  iso_storage_pool = var.iso_storage_pool
  iso_checksum     = var.iso_checksum == "" ? local.remote_image_checksums[local.image_name] : var.iso_checksum

  node               = var.proxmox_node
  ssh_username       = "ubuntu"
  vm_name            = "pve-packer-ubuntu-{{timestamp}}"
  cloud_init         = true
  serials            = ["socket"]
  qemu_agent         = true
  ballooning_minimum = 512
  memory             = 1024
  cpu_type           = "host"
  os                 = "l26"
  scsi_controller    = "virtio-scsi-pci"

  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = true
  }

  disks {
    disk_size    = "16G"
    storage_pool = var.vm_storage_pool
    type         = "scsi"
    cache_mode   = "writeback"
  }
}

build {
  sources = ["source.proxmox-iso.ubuntu"]
}
