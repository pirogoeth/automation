terraform {
  backend "pg" {}

  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.2"
    }
  }
}

provider "minio" {
  minio_server   = var.minio_server
  minio_user     = var.minio_username
  minio_password = var.minio_password
  minio_ssl      = var.minio_ssl
}
