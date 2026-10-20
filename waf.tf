locals {
  # true = log only (observe). Switch to false to start blocking.
  waf_count_mode = true

  waf_managed_rule_groups = {
    "AWSManagedRulesAmazonIpReputationList" = 10
    "AWSManagedRulesCommonRuleSet"          = 20
    "AWSManagedRulesKnownBadInputsRuleSet"  = 30
    "AWSManagedRulesSQLiRuleSet"            = 40
  }
}

resource "aws_wafv2_web_acl" "bank" {
  name  = "cymbal-bank-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-per-ip"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = local.waf_managed_rule_groups
    content {
      name     = rule.key
      priority = rule.value

      override_action {
        dynamic "count" {
          for_each = local.waf_count_mode ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = local.waf_count_mode ? [] : [1]
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cymbal-bank-web-acl"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-cymbal-bank"
  retention_in_days = 30
}

resource "aws_wafv2_web_acl_logging_configuration" "bank" {
  resource_arn            = aws_wafv2_web_acl.bank.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.bank.arn
}
