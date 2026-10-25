module "core_nodes" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 20.0"

  name            = "core_nodes"
  cluster_name    = module.eks_cluster.cluster_name
  cluster_version = module.eks_cluster.cluster_version
  subnet_ids      = module.vpc.private_subnets

  cluster_primary_security_group_id = module.eks_cluster.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks_cluster.node_security_group_id]
  cluster_service_cidr              = module.eks_cluster.cluster_service_cidr

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["m7i-flex.large"]

  min_size     = 2
  max_size     = 4
  desired_size = 2

  # Nodes have no CNI until Cilium runs; joining after Cilium lets them become
  # Ready (otherwise EKS fails the node group with NodeCreationFailure)
  depends_on = [helm_release.cilium]
}
