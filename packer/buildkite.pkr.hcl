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

variable "proxmox_skip_tls_verify" {
  type    = string
  default = ""
}

variable "source_vm_id" {
  type    = string
  default = ""
}

variable "ssh_bastion_host" {
  type    = string
  default = ""
}

variable "ssh_bastion_port" {
  type    = number
  default = 22
}

variable "ssh_bastion_agent_auth" {
  type    = bool
  default = false
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

variable "build_time" {
  type    = string
  default = "{{timestamp}}"
}

locals {
  template_prefix = "ubuntu-buildkite"
}

source "proxmox-clone" "buildkite" {
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
  insecure_skip_tls_verify = try(convert(var.proxmox_skip_tls_verify, bool), false)
  task_timeout             = "5m"

  clone_vm_id        = var.source_vm_id
  node               = var.proxmox_node
  ssh_username       = "ubuntu"
  vm_name            = "packer-pve-buildkite-${var.build_time}"
  serials            = ["socket"]
  qemu_agent         = true
  cloud_init         = true
  scsi_controller    = "virtio-scsi-pci"
  cpu_type           = "host"
  os                 = "l26"
  ballooning_minimum = 512
  memory             = 1024

  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = true
  }

  ipconfig {
    ip  = "dhcp"
    ip6 = "auto"
  }
}

build {
  name = "buildkite"
  source "proxmox-clone.buildkite" {
    template_name = "${local.template_prefix}-${var.build_time}"
  }

  provisioner "ansible-local" {
    playbook_file = "ansible/play-buildkite.yml"
    role_paths = [
      "ansible/roles/common",
      "ansible/roles/buildkite",
    ]
    command = "~${build.User}/.local/bin/ansible-playbook"
    extra_arguments = [
      "-e", "packer_image_type=${build.name}",
    ]
    inventory_groups = ["packer_${build.name}"]
    galaxy_file      = "ansible/roles/requirements.yml"
    galaxy_command   = "~${build.User}/.local/bin/ansible-galaxy"
    group_vars       = "ansible/inventory/group_vars"
  }

  post-processor "manifest" {
    output     = "manifests/packer-buildkite.json"
    strip_path = true
    custom_data = {
      template_name = "${local.template_prefix}-${var.build_time}"
    }
  }
}
