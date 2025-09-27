output "nomad_server_inventory" {
  value = module.nomad_server_instances.inventory
}

output "nomad_client_inventory" {
  value = concat(
    module.nomad_client_default_instances.inventory,
    module.nomad_client_gpu_instances.inventory,
  )
}

output "compute_instance_inventory" {
  value = module.docker_compute_instances.inventory
}

output "gpu_instance_inventory" {
  value = module.docker_gpu_instances.inventory
}

output "minio_server_inventory" {
  value = module.minio_instances.inventory
}

