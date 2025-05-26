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
  template_prefix = "ubuntu-k3s"
}

source "proxmox-clone" "k3s" {
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
  vm_name            = "packer-pve-k3s-${var.build_time}"
  serials            = ["socket"]
  qemu_agent         = true
  cloud_init         = true
  scsi_controller    = "virtio-scsi-pci"
  cpu_type           = "host"
  os                 = "l26"
  sockets            = 1
  cores              = 2
  ballooning_minimum = 512
  memory             = 8192
  pool               = "k3s"

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
  name = "k3s-leader"
  source "proxmox-clone.k3s" {
    template_name = "${local.template_prefix}-leader-${var.build_time}"
  }

  provisioner "ansible-local" {
    playbook_file = "ansible/play-k3s.yml"
    role_paths = [
      "ansible/roles/common",
      "ansible/roles/base",
      "ansible/roles/docker",
      "ansible/roles/k3s",
    ]
    command = "~${build.User}/.local/bin/ansible-playbook"
    extra_arguments = [
      "-e", "packer_image_type=${build.name}",
    ]
    inventory_groups = ["packer_${build.name}", "k3s_leader"]
    galaxy_file      = "ansible/roles/requirements.yml"
    galaxy_command   = "~${build.User}/.local/bin/ansible-galaxy"
    group_vars       = "ansible/inventory/group_vars"
  }

  post-processor "manifest" {
    output     = "manifests/packer-k3s.json"
    strip_path = true
    custom_data = {
      template_name = "${local.template_prefix}-leader-${var.build_time}"
    }
  }
}

build {
  name = "k3s-agent"
  source "proxmox-clone.k3s" {
    template_name = "${local.template_prefix}-agent-${var.build_time}"
  }

  provisioner "ansible-local" {
    playbook_file = "ansible/play-k3s.yml"
    role_paths = [
      "ansible/roles/common",
      "ansible/roles/base",
      "ansible/roles/docker",
      "ansible/roles/k3s",
    ]
    command = "~${build.User}/.local/bin/ansible-playbook"
    extra_arguments = [
      "-e", "packer_image_type=${build.name}",
    ]
    inventory_groups = ["packer_${build.name}", "k3s_agent"]
    galaxy_file      = "ansible/roles/requirements.yml"
    galaxy_command   = "~${build.User}/.local/bin/ansible-galaxy"
    group_vars       = "ansible/inventory/group_vars"
  }

  post-processor "manifest" {
    output     = "manifests/packer-k3s.json"
    strip_path = true
    custom_data = {
      template_name = "${local.template_prefix}-agent-${var.build_time}"
    }
  }
}
