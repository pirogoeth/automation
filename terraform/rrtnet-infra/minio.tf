module "minio_instances" {
  source = "../modules/proxmox-instances"

  proxmox_node          = var.proxmox_node
  proxmox_resource_pool = "minio"
  instance_prefix       = "minio"
  startup_options       = "order=5,up=10"

  # source_template = local.last_image.custom_data.template_name
  source_template = "ubuntu-jammy-docker-1701992627"

  authorized_keys_file = abspath(join("/", [path.module, "..", "..", "resources", "authorized_keys"]))

  domain_name = "s.2811rrt.net"
  nameserver  = "10.100.0.11"

  # 10.100.10.8 -> 10.100.10.15 (7 hosts available)
  subnet          = "10.100.10.8/29"
  network_gateway = "10.100.10.1"

  instance_count = 1
  shape = {
    cores          = 2
    sockets        = 2
    memory         = 1024 * 16
    memory_balloon = 512
    storage_type   = "virtio"
    storage_id     = "local-lvm"
    user           = "ubuntu"
    network_bridge = "vmbr1"
    network_tag    = 20

    disk_size = "64G"
    extra_disks = [
      {
        type    = "virtio"
        size    = "64G"
        storage = "ext1"
      },
      {
        type    = "virtio"
        size    = "64GG"
        storage = "ext2"
      },
      {
        type    = "virtio"
        size    = "64G"
        storage = "ext3"
      },
    ]
  }
}

