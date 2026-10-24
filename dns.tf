provider "cloudflare" {}

# The subdomain zone, owned by this account
resource "aws_route53_zone" "main" {
  name = "o.serghini.me"
}

# The parent zone, which stays on Cloudflare
data "cloudflare_zone" "parent" {
  filter = {
    name = "serghini.me"
  }
}

# Delegation: "for o.serghini.me, ask these Route53 nameservers"
resource "cloudflare_dns_record" "o_delegation" {
  count = 4

  zone_id = data.cloudflare_zone.parent.zone_id
  name    = "o.serghini.me"
  type    = "NS"
  content = aws_route53_zone.main.name_servers[count.index]
  ttl     = 3600
}
