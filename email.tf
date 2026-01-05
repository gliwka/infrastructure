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

  # Flatten MX records
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

  # Flatten DKIM records
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

resource "bunnynet_dns_record" "bunny_mx" {
  for_each = { for item in local.mx_flat : item.key => item }

  zone  = bunnynet_dns_zone.zone[each.value.domain].id
  type     = "MX"
  name     = ""
  
  value    = lower(each.value.value)
  
  priority = each.value.priority
  ttl      = 1800
}

resource "bunnynet_dns_record" "bunny_dkim" {
  for_each = { for item in local.dkim_flat : lower(item.key) => item }

  zone = bunnynet_dns_zone.zone[each.value.domain].id
  type    = "CNAME"
  name    = lower(each.value.name)
  
  value   = lower(each.value.value)
  
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