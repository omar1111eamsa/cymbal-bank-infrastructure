resource "aws_secretsmanager_secret" "alertmanager_slack" {
  name        = "cymbal-bank/monitoring/alertmanager-slack"
  description = "Slack incoming webhook URL for Alertmanager"
}

module "external_secrets_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                                          = "external-secrets"
  attach_external_secrets_policy                     = true
  external_secrets_secrets_manager_arns              = ["arn:aws:secretsmanager:eu-west-1:612062119472:secret:cymbal-bank/*"]
  external_secrets_ssm_parameter_arns                = []
  external_secrets_secrets_manager_create_permission = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}
