# Account guardrail: email when spend is heading over the monthly limit
variable "budget_email" {
  description = "Address that receives budget alerts"
  type        = string
}

resource "aws_budgets_budget" "monthly" {
  name         = "cymbal-bank-monthly"
  budget_type  = "COST"
  limit_amount = "50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Early warning: real spend passed 50%
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  # Forecast: at this pace we'll pass 100% by month end
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
