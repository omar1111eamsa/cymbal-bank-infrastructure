module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

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
}
