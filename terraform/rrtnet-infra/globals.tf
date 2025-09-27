data "local_file" "manifest" {
  filename = abspath(join("/", [path.module, "..", "..", "manifests", "packer-docker.json"]))
}

locals {
  manifest      = jsondecode(data.local_file.manifest.content)
  last_run_uuid = local.manifest.last_run_uuid
  last_image    = [for build in local.manifest.builds : build if build.packer_run_uuid == local.last_run_uuid][0]
}
