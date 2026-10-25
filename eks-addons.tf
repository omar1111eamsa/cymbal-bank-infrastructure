# Add-ons run on nodes, so they wait for the node group (which waits for Cilium)
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = module.eks_cluster.cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.4.1-eksbuild.2"

  depends_on = [module.core_nodes]
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = module.eks_cluster.cluster_name
  addon_name    = "coredns"
  addon_version = "v1.14.7-eksbuild.11"

  depends_on = [module.core_nodes]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks_cluster.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.67.1-eksbuild.1"
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  depends_on = [module.core_nodes]
}
