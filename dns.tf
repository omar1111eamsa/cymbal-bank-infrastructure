# The zone lives in the persistent layer (persistent/dns.tf); the
# ephemeral environment only reads it, so destroy never touches DNS.
data "aws_route53_zone" "main" {
  name = "o.serghini.me"
}
