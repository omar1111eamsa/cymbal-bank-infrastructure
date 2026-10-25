# o.assfah.me is hosted in Route53; assfah.me stays at Namecheap
resource "aws_route53_zone" "main" {
  name = "o.assfah.me"
}

# Add these 4 as NS records for host "o" in Namecheap (once)
output "nameservers" {
  value = aws_route53_zone.main.name_servers
}
