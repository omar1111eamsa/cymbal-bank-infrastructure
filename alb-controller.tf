module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.12"

  name                            = "aws-load-balancer-controller"
  attach_aws_lb_controller_policy = true
  attach_custom_policy            = true
  policy_statements = [
    {
      sid       = "WafLookupByName"
      actions   = ["wafv2:ListWebACLs"]
      resources = ["*"]
    }
  ]

  associations = {
    this = {
      cluster_name    = module.eks_cluster.cluster_name
      namespace       = "aws-load-balancer-controller"
      service_account = "aws-load-balancer-controller"
    }
  }
}
