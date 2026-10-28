data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# The secrets themselves live in the persistent layer (persistent/secrets.tf);
# ESO here only gets read access to cymbal-bank/*.
module "external_secrets_pod_identity" {
  # checkov:skip=CKV_TF_1: registry module, pinned to an exact version (registry sources can't use a commit hash)
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.12.1"

  name                                  = "external-secrets"
  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:cymbal-bank/*"]
  external_secrets_ssm_parameter_arns   = []
  external_secrets_create_permission    = false

  associations = {
    this = {
      cluster_name    = module.eks_cluster.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }
}
