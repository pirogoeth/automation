terraform {
  backend "pg" {}

  required_providers {
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }
  }
}

provider "dns" {
  update {
    transport     = "tcp"
    server        = var.dns_server
    key_name      = var.dns_key_name
    key_algorithm = var.dns_key_algo
    key_secret    = var.dns_key_secret
  }
}


