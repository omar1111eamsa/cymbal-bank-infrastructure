module "external_dns_pod_identity" {
  # checkov:skip=CKV_TF_1: registry module, pinned to an exact version (registry sources can't use a commit hash)
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.12.1"

  name                          = "external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [data.aws_route53_zone.main.arn]

  associations = {
    this = {
      cluster_name    = module.eks_cluster.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns"
    }
  }
}
