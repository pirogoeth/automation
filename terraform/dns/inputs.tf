variable "service_base_domain" {
  type    = string
  default = "example.org"
}

variable "dns_server" {
  type = string
}

variable "dns_key_name" {
  type = string
}

variable "dns_key_algo" {
  type = string
}

variable "dns_key_secret" {
  type      = string
  sensitive = true
}

variable "traefik_hosts" {
  type = list(string)
}
