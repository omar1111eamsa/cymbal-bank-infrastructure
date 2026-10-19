module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                     = "external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [data.aws_route53_zone.main.arn]

  oidc_providers = {
    main = {
      provider_arn = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = [
        "kube-system:external-dns",
        "external-dns:external-dns",
      ]
    }
  }
}


resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"

  values = [
    yamlencode({
      provider      = { name = "aws" }
      env           = [{ name = "AWS_DEFAULT_REGION", value = "eu-west-1" }]
      domainFilters = ["o.serghini.me"]
      policy        = "sync"
      registry      = "txt"
      txtOwnerId    = module.eks_cluster.cluster_name
      sources       = ["ingress"]
      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.external_dns_irsa_role.iam_role_arn
        }
      }
    })
  ]
}
