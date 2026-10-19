data "aws_route53_zone" "main" {
  name = "o.serghini.me"
}

resource "aws_acm_certificate" "bank" {
  domain_name       = "bank.o.serghini.me"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "bank_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.bank.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "bank" {
  certificate_arn = aws_acm_certificate.bank.arn
  validation_record_fqdns = [
    for r in aws_aws_route53_record.bank_cert_validation : r.fqdn
  ]
}

output "bank_certificate_arn" {
  value = aws_acm_certificate_validation.bank.certificate_arn
}
