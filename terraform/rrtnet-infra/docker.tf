module "docker_compute_instances" {
  source = "../modules/proxmox-instances"

  proxmox_node          = var.proxmox_node
  proxmox_resource_pool = "docker-workload"
  instance_prefix       = "docker"
  startup_options       = "order=10,up=60"

  source_template = local.last_image.custom_data.template_name

  authorized_keys_file = abspath(join("/", [path.module, "..", "..", "resources", "authorized_keys"]))

  domain_name = "c.2811rrt.net"
  nameserver  = "10.100.0.11"

  # 10.100.10.80 -> 10.100.10.95 (14 hosts available)
  subnet          = "10.100.10.80/28"
  network_gateway = "10.100.10.1"

  instance_count = 1
  shape = {
    cores          = 8
    sockets        = 1
    memory         = 1024 * 32
    storage_type   = "virtio"
    storage_id     = "local-lvm"
    user           = "ubuntu"
    network_bridge = "vmbr1"
    network_tag    = 20

    disk_size = "128G"
    extra_disks = [
      {
        type    = "virtio"
        size    = "512G"
        storage = "ext1"
      },
      {
        type    = "virtio"
        size    = "512G"
        storage = "ext2"
      },
      {
        type    = "virtio"
        size    = "512G"
        storage = "ext3"
      },
    ]
  }
  attributes = {
    "system_roles" = [
      "docker",
      "compute",
    ]
  }
}

module "docker_gpu_instances" {
  source = "../modules/proxmox-instances"

  proxmox_node          = var.proxmox_node
  proxmox_resource_pool = "docker-workload"
  instance_prefix       = "docker-gpu"
  startup_options       = "order=10,up=60"

  source_template = local.last_image.custom_data.template_name

  authorized_keys_file = abspath(join("/", [path.module, "..", "..", "resources", "authorized_keys"]))

  domain_name = "c.2811rrt.net"
  nameserver  = "10.100.0.11"

  # 10.100.10.96 -> 10.100.10.110 (14 hosts available)
  subnet          = "10.100.10.96/28"
  network_gateway = "10.100.10.1"

  instance_count = 1
  shape = {
    cores          = 8
    sockets        = 1
    memory         = 1024 * 32
    storage_type   = "virtio"
    storage_id     = "local-lvm"
    user           = "ubuntu"
    network_bridge = "vmbr1"
    network_tag    = 20

    disk_size = "128G"
    extra_disks = [
      {
        type    = "virtio"
        size    = "512G"
        storage = "ext1"
      },
      {
        type    = "virtio"
        size    = "512G"
        storage = "ext2"
      },
      {
        type    = "virtio"
        size    = "512G"
        storage = "ext3"
      },
    ]
  }
  attributes = {
    "system_roles" = [
      "docker",
      "compute",
      "gpu",
    ]
  }
}
