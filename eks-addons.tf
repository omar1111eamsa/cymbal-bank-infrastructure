resource "aws_eks_addon" "coredns" {
  cluster_name  = module.eks_cluster.cluster_name
  addon_name    = "coredns"
  addon_version = "v1.14.7-eksbuild.11"

  depends_on = [helm_release.cilium]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks_cluster.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.67.1-eksbuild.1"
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  depends_on = [helm_release.cilium]
}
