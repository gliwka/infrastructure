locals {
  emailDomains = toset(["gliwka.eu", "gliwka.de", "cerebuild.com"])

  # MX Configuration
  mx_config = [
    { priority = 10, value = "mxext1.mailbox.org" },
    { priority = 10, value = "mxext2.mailbox.org" },
    { priority = 20, value = "mxext3.mailbox.org" }
  ]

  # DKIM Selectors
  dkim_selectors = ["MBO0001", "MBO0002", "MBO0003", "MBO0004"]

  # Strings
  spf_record   = "v=spf1 include:mailbox.org include:_spf.google.com ~all"
  dmarc_record = "v=DMARC1; p=reject; rua=mailto:postmaster@gliwka.eu; adkim=s; aspf=s;"

  # Flatten MX records (For Bunny)
  mx_flat = flatten([
    for domain in local.emailDomains : [
      for mx in local.mx_config : {
        key      = "${domain}-${mx.value}"
        domain   = domain
        value    = mx.value
        priority = mx.priority
      }
    ]
  ])

  # Flatten DKIM records (For Bunny)
  dkim_flat = flatten([
    for domain in local.emailDomains : [
      for sel in local.dkim_selectors : {
        key      = "${domain}-${sel}"
        domain   = domain
        name     = "${sel}._domainkey"
        value    = "${sel}._domainkey.mailbox.org"
      }
    ]
  ])
}

# ==============================================================================
# GROUP 1: GANDI LIVE DNS (Names restored to preserve state)
# ==============================================================================

resource "gandi_livedns_record" "mx" {
  for_each = local.emailDomains
  
  zone   = each.key
  name   = "@"
  type   = "MX"
  ttl    = 18000
  values = [
    for mx in local.mx_config : "${mx.priority} ${mx.value}." 
  ]
}

# We must keep dkim_1..4 separate to match your existing state file
resource "gandi_livedns_record" "dkim_1" {
  for_each = local.emailDomains
  zone     = each.key
  name     = "${local.dkim_selectors[0]}._domainkey"
  type     = "CNAME"
  ttl      = 18000
  values   = ["${local.dkim_selectors[0]}._domainkey.mailbox.org."]
}

resource "gandi_livedns_record" "dkim_2" {
  for_each = local.emailDomains
  zone     = each.key
  name     = "${local.dkim_selectors[1]}._domainkey"
  type     = "CNAME"
  ttl      = 18000
  values   = ["${local.dkim_selectors[1]}._domainkey.mailbox.org."]
}

resource "gandi_livedns_record" "dkim_3" {
  for_each = local.emailDomains
  zone     = each.key
  name     = "${local.dkim_selectors[2]}._domainkey"
  type     = "CNAME"
  ttl      = 18000
  values   = ["${local.dkim_selectors[2]}._domainkey.mailbox.org."]
}

resource "gandi_livedns_record" "dkim_4" {
  for_each = local.emailDomains
  zone     = each.key
  name     = "${local.dkim_selectors[3]}._domainkey"
  type     = "CNAME"
  ttl      = 18000
  values   = ["${local.dkim_selectors[3]}._domainkey.mailbox.org."]
}

resource "gandi_livedns_record" "spf" {
  for_each = local.emailDomains
  zone     = each.key
  name     = "@"
  type     = "TXT"
  ttl      = 18000
  values   = ["\"${local.spf_record}\""]
}

resource "gandi_livedns_record" "dmarc" {
  for_each = local.emailDomains
  zone     = each.key
  name     = "_dmarc"
  type     = "TXT"
  ttl      = 18000
  values   = ["\"${local.dmarc_record}\""]
}

# ==============================================================================
# GROUP 2: BUNNY.NET DNS
# ==============================================================================

resource "bunnynet_dns_record" "bunny_mx" {
  for_each = { for item in local.mx_flat : item.key => item }
  zone  = bunnynet_dns_zone.zone[each.value.domain].id
  
  type     = "MX"
  name     = ""
  value    = each.value.value
  priority = each.value.priority
  ttl      = 1800
}

resource "bunnynet_dns_record" "bunny_dkim" {
  for_each = { for item in local.dkim_flat : item.key => item }

  zone = bunnynet_dns_zone.zone[each.value.domain].id
  type    = "CNAME"
  name    = each.value.name
  value   = each.value.value
  ttl     = 1800
}

resource "bunnynet_dns_record" "bunny_spf" {
  for_each = local.emailDomains

  zone = bunnynet_dns_zone.zone[each.key].id
  type    = "TXT"
  name    = ""
  value   = local.spf_record
  ttl     = 1800
}

resource "bunnynet_dns_record" "bunny_dmarc" {
  for_each = local.emailDomains

  zone = bunnynet_dns_zone.zone[each.key].id
  type    = "TXT"
  name    = "_dmarc"
  value   = local.dmarc_record
  ttl     = 1800
}