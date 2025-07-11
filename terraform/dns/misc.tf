locals {
  misc_a_records = [
    { sub = "dns", domain = "${var.service_base_domain}", to = ["10.100.0.11"] },
    { sub = "godoxy", domain = "${var.service_base_domain}", to = ["10.100.0.7"] },
    { sub = "nvr", domain = "${var.service_base_domain}", to = ["10.100.10.18"] },
    { sub = "*.nvr", domain = "${var.service_base_domain}", to = ["10.100.10.18"] },
    { sub = "mqtt", domain = "${var.service_base_domain}", to = ["10.100.0.14"] },
    { sub = "sheets", domain = var.service_base_domain, to = ["10.100.0.7"] },
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

