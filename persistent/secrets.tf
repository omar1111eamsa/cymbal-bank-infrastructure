# Values are set once in Secrets Manager (never in Terraform or Git)
# and survive destroy/rebuild of the ephemeral environment.
resource "aws_secretsmanager_secret" "alertmanager_slack" {
  name        = "cymbal-bank/monitoring/alertmanager-slack"
  description = "Slack incoming webhook URL for Alertmanager"
}
