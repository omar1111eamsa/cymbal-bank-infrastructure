module "karpenter" {
  # checkov:skip=CKV_TF_1: registry module, pinned to an exact version (registry sources can't use a commit hash)
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.37.2"

  cluster_name = module.eks_cluster.cluster_name

  # Pod Identity, the same method as our other controllers
  enable_pod_identity             = true
  create_pod_identity_association = true
  namespace                       = "kube-system"
  service_account                 = "karpenter"

  # Fixed name, so the EC2NodeClass in Git can reference it (no account ID needed)
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "KarpenterNodeRole-cymbal-bank"

  # SSM lets you open a shell on a node without SSH keys
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Karpenter 1.15 lists its own instance profiles (cleanup); the module's built-in policy predates it.
  # Scoped to Karpenter's path for this cluster only.
  iam_policy_statements = [
    {
      sid       = "AllowListOwnInstanceProfiles"
      actions   = ["iam:ListInstanceProfiles"]
      resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/karpenter/${data.aws_region.current.name}/${module.eks_cluster.cluster_name}/*"]
    },
    {
      # Read-only; EC2 Describe* actions can't be scoped to resources
      sid       = "AllowInstanceStatusHealthChecks"
      actions   = ["ec2:DescribeInstanceStatus"]
      resources = ["*"]
    }
  ]
}


# CRDs as their own release: Helm never upgrades CRDs shipped inside a chart
resource "helm_release" "karpenter_crd" {
  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = "1.15.1"
  namespace  = "kube-system"

  depends_on = [module.core_nodes]
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.15.1"
  namespace  = "kube-system"
  skip_crds  = true

  values = [yamlencode({
    serviceAccount = { name = module.karpenter.service_account }
    settings = {
      clusterName       = module.eks_cluster.cluster_name
      clusterEndpoint   = module.eks_cluster.cluster_endpoint
      interruptionQueue = module.karpenter.queue_name
    }
    controller = {
      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { memory = "512Mi" }
      }
    }
  })]

  # Needs the Pod Identity agent (AWS credentials) and CoreDNS (to resolve AWS APIs)
  depends_on = [
    helm_release.karpenter_crd,
    aws_eks_addon.pod_identity_agent,
    aws_eks_addon.coredns,
  ]
}
