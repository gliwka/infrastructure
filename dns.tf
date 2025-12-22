locals {
  managed = toset(["gliwka.eu", "gliwka.de", "cerebuild.com"])
}

resource "gandi_livedns_domain" "livedns" {
    for_each = local.managed
    name = each.key
    automatic_snapshots = true
}

resource "bunnynet_dns_zone" "zone" {
  for_each = local.managed
  domain   = each.key
}
