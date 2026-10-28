# o.assfah.me is hosted in Route53; assfah.me stays at Namecheap
resource "aws_route53_zone" "main" {
  # checkov:skip=CKV2_AWS_38: parent zone assfah.me is at Namecheap, which can't publish a DS record for a subdomain; DNSSEC would have no chain of trust
  # checkov:skip=CKV2_AWS_39: public query logs (us-east-1 log group) not worth the cost for a demo domain
  name = "o.assfah.me"
}

# Add these 4 as NS records for host "o" in Namecheap (once)
output "nameservers" {
  value = aws_route53_zone.main.name_servers
}
