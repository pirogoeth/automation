data "terraform_remote_state" "infra" {
  backend   = "pg"
  workspace = "nomad-main-infra"
}

data "terraform_remote_state" "object_storage" {
  backend   = "pg"
  workspace = "object-storage"
}
