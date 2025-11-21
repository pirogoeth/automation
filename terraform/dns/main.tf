locals {
  misc_a_records = [
    { sub = "dns", domain = var.service_base_domain, to = ["10.100.0.11"] },
    { sub = "nvr", domain = var.service_base_domain, to = ["10.100.10.18"] },
    { sub = "*.nvr", domain = var.service_base_domain, to = ["10.100.10.18"] },
    { sub = "mqtt", domain = var.service_base_domain, to = ["10.100.0.14"] },
  ]
}

resource "dns_a_record_set" "misc" {
  for_each = {
    for record in local.misc_a_records :
    ("${record.sub}.${record.domain}") => record
    if !try(record.disabled, false)
  }

  zone      = endswith(each.value.domain, ".") ? each.value.domain : "${each.value.domain}."
  name      = each.value.sub
  addresses = flatten(tolist(each.value.to))
  ttl       = try(each.value.ttl, 300)
}

locals {
  traefik_addresses = var.traefik_hosts

  minio_addresses = [
    for item in data.terraform_remote_state.infra.outputs.minio_server_inventory
    : item.ip
  ]
}

resource "dns_a_record_set" "traefik" {
  zone      = "${var.service_base_domain}."
  name      = "traefik"
  addresses = local.traefik_addresses
  ttl       = 300
}

resource "dns_a_record_set" "minio" {
  zone      = "${var.service_base_domain}."
  name      = "s3"
  addresses = local.minio_addresses
  ttl       = 300
}

resource "dns_cname_record" "minio_glob" {
  zone  = "${var.service_base_domain}."
  name  = "*.s3"
  cname = dns_a_record_set.minio.id
  ttl   = 300
}

resource "dns_cname_record" "services" {
  zone  = "${var.service_base_domain}."
  name  = "*"
  cname = dns_a_record_set.traefik.id
  ttl   = 3600
}


