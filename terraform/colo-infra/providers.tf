terraform {
  backend "pg" {}

  required_providers {
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.2"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "nomad" {
  address     = var.nomad_url
  ca_file     = var.ca_cert
  cert_file   = var.cli_cert
  key_file    = var.cli_key
  skip_verify = var.tls_skip_verify
  secret_id   = var.secret_id
}

provider "minio" {
  minio_server   = var.minio_server
  minio_user     = var.minio_username
  minio_password = var.minio_password
  minio_ssl      = var.minio_ssl
}

provider "dns" {
  update {
    server        = var.dns_server
    key_name      = var.dns_key_name
    key_algorithm = var.dns_key_algo
    key_secret    = var.dns_key_secret
  }
}

