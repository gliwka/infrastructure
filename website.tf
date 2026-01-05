locals {
    website_domain = "gliwka.eu"
}

resource "bunnynet_storage_zone" "website_storage" {
  name      = "gliwka-eu-storage"
  region    = "DE"
  zone_tier = "Edge"
  replication_regions = ["NY", "LA", "SG", "SYD", "UK", "SE", "BR", "JH"]
  custom_404_file_path = "/404.html"
}

resource "bunnynet_storage_zone" "website_log_storage" {
  name      = "gliwka-eu-logs"
  region    = "DE"
  zone_tier = "Standard"
  replication_regions = []
}

resource "bunnynet_pullzone" "website_cdn" {
  name = "gliwka-eu-cdn"

  log_enabled = true
  log_storage_enabled = true
  log_storage_zone = bunnynet_storage_zone.website_log_storage.id
  log_anonymized = true
  log_anonymized_style = "OneDigit" # Drop last octet

  cache_enabled = true
  cache_expiration_time = 60 * 60 * 24 * 365

  origin {
    type = "StorageZone"
    storagezone = bunnynet_storage_zone.website_storage.id
  }

  routing {
    tier = "Standard"
  }
}

resource "bunnynet_pullzone_hostname" "website_cdn_domain" {
  pullzone    = bunnynet_pullzone.website_cdn.id
  name        = local.website_domain
  tls_enabled = true
  force_ssl   = true
}

resource "bunnynet_dns_record" "website_cdn_dns" {
  zone = bunnynet_dns_zone.zone[local.website_domain].id
  name  = ""
  type  = "PullZone"
  value = bunnynet_pullzone.website_cdn.name
  pullzone_id = bunnynet_pullzone.website_cdn.id
}

resource "bunnynet_dns_record" "website_www_redirect" {
  zone = bunnynet_dns_zone.zone[local.website_domain].id
  name  = "www"
  type  = "Redirect"
  value = "https://${local.website_domain}"
}

resource "bunnynet_dns_record" "website_google_verify" {
  zone = bunnynet_dns_zone.zone[local.website_domain].id
  name  = ""
  type  = "TXT"
  value = "google-site-verification=vwdtT1ZmNH3A_3MSbEVGBtnv0x2zjAUkzyBEHpwc_SQ"
}