moved {
  from = module.server_instances
  to   = module.nomad_server_instances
}

module "nomad_server_instances" {
  source = "../modules/proxmox-instances"

  proxmox_node          = var.proxmox_node
  proxmox_resource_pool = "nomad-main-2"
  instance_prefix       = "nomad-main-server"
  startup_options       = "order=1,up=0"

  # source_template = local.last_image.custom_data.template_name
  source_template = "ubuntu-jammy-docker-1701992627"

  authorized_keys_file = abspath(join("/", [path.module, "..", "..", "resources", "authorized_keys"]))

  domain_name = "nm2.2811rrt.net"
  nameserver  = "10.100.0.11"

  # 10.100.10.64 -> 10.100.10.79 (14 hosts available)
  subnet          = "10.100.10.64/28"
  network_gateway = "10.100.10.1"

  instance_count = 3
  shape = {
    cores          = 1
    sockets        = 1
    memory         = 1024 * 2
    memory_balloon = 0
    storage_type   = "virtio"
    storage_id     = "local-lvm"
    user           = "ubuntu"
    network_bridge = "vmbr1"
    network_tag    = 20

    disk_size = "128G"
  }
  attributes = {
    "nomad_role" = "server"
  }
}

moved {
  from = module.client_default_instances
  to   = module.nomad_client_default_instances
}

module "nomad_client_default_instances" {
  source = "../modules/proxmox-instances"

  proxmox_node          = var.proxmox_node
  proxmox_resource_pool = "nomad-main-2"
  instance_prefix       = "nomad-main-client"
  startup_options       = "order=50,up=60"

  # source_template = local.last_image.custom_data.template_name
  source_template = "ubuntu-jammy-docker-1701992627"

  authorized_keys_file = abspath(join("/", [path.module, "..", "..", "resources", "authorized_keys"]))

  domain_name = "nm2.2811rrt.net"
  nameserver  = "10.100.0.11"

  # 10.100.10.32 -> 10.100.10.47 (14 hosts available)
  subnet          = "10.100.10.32/28"
  network_gateway = "10.100.10.1"

  instance_count = 1
  shape = {
    cores          = 8
    sockets        = 1
    memory         = 1024 * 32
    memory_balloon = 0
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
    "nomad_role"      = "client"
    "nomad_node_pool" = "default"
  }
}

moved {
  from = module.client_gpu_instances
  to   = module.nomad_client_gpu_instances
}

module "nomad_client_gpu_instances" {
  source = "../modules/proxmox-instances"

  proxmox_node          = var.proxmox_node
  proxmox_resource_pool = "nomad-main-2"
  instance_prefix       = "nomad-main-gpu"
  startup_options       = "order=50,up=60"

  # source_template = local.last_image.custom_data.template_name
  source_template = "ubuntu-jammy-docker-1701992627"

  authorized_keys_file = abspath(join("/", [path.module, "..", "..", "resources", "authorized_keys"]))

  domain_name = "nm2.2811rrt.net"
  nameserver  = "10.100.0.11"

  # 10.100.10.48 -> 10.100.10.63 (14 hosts available)
  subnet          = "10.100.10.48/28"
  network_gateway = "10.100.10.1"

  instance_count = 1
  shape = {
    cores          = 8
    sockets        = 1
    memory         = 1024 * 48
    memory_balloon = 1024 * 16
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
    "nomad_role"      = "client"
    "nomad_node_pool" = "gpu"
  }
}

