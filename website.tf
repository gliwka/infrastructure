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

  tls_support = [] # Disable legacy TLS versions (1.0, 1.1)

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


resource "bunnynet_pullzone_edgerule" "website_security_headers" {
  enabled     = true
  pullzone    = bunnynet_pullzone.website_cdn.id

  actions = [
    {
      type       = "SetResponseHeader"
      parameter1 = "X-Frame-Options"
      parameter2 = "DENY"
      parameter3 = null
    },
    {
      type       = "SetResponseHeader"
      parameter1 = "X-Content-Type-Options"
      parameter2 = "nosniff"
      parameter3 = null
    },
    {
      type       = "SetResponseHeader"
      parameter1 = "Referrer-Policy"
      parameter2 = "strict-origin-when-cross-origin"
      parameter3 = null
    },
    {
      type       = "SetResponseHeader"
      parameter1 = "Strict-Transport-Security"
      parameter2 = "max-age=63072000; includeSubDomains; preload"
      parameter3 = null
    },
    {
      type       = "SetResponseHeader"
      parameter1 = "Cross-Origin-Opener-Policy"
      parameter2 = "same-origin"
      parameter3 = null
    },
    {
      type       = "SetResponseHeader"
      parameter1 = "Permissions-Policy"
      # Disable all currently known features, c.f. https://www.permissionspolicy.com. Also opt out of FLoC tracking for our users.
      parameter2 = "accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), interest-cohort=()"
      parameter3 = null
    },
    {
      type       = "SetResponseHeader"
      parameter1 = "Content-Security-Policy"
      parameter2 = "default-src 'self'; frame-ancestors 'none'; upgrade-insecure-requests"
      parameter3 = null
    },
  ]

  match_type = "MatchAny"
  triggers = [
    {
      type       = "Url"
      match_type = "MatchAny"
      patterns   = ["https://${local.website_domain}/*"]
      parameter1 = null
      parameter2 = null
    }
  ]
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

resource "bunnynet_dns_record" "website_newsletter_dkim" {
  zone = bunnynet_dns_zone.zone[local.website_domain].id
  name  = "lettermint._domainkey"
  type  = "TXT"
  value = "v=DKIM1;k=rsa;p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsed6vM5Qq5JEalyP9/E9++CVX6Vtp0qfqBnllDFeoNb44Ho3fdEUpd9fPMGlTHAd5FU6vqLi5fS7sxgb9nrDzfB/sbz0DSWfIceXteTB7TMaSQajg+UTLLe5tB9SCw39hAUONmlIsLfMMt6qKCfIYQEx8rglo4haP0AFsBxj+vzfDhGh4uOexuw7IpgVsPlq2RjUhasZzbd3m/m8jRHRRUmU2mN/fNzxROmkqFeyfYKd33EGfAjd+7RULhkWiTViPrFbJjSYF5jmYam8lspvK2ma0pmHWNPjJwUsWA8hRUDemI9b9sU8efEGQAmRgZ9cMOwGMfBDyIgAFEH0UjRXzQIDAQAB"
}

resource "bunnynet_dns_record" "website_newsletter_bounces" {
  zone = bunnynet_dns_zone.zone[local.website_domain].id
  name  = "lm-bounces"
  type  = "CNAME"
  value = "bounces.lmta.net"
}