# Nodes have no CNI until Cilium runs; joining after Cilium lets them become
# Ready (otherwise EKS fails the node group with NodeCreationFailure).
# The order comes through this value, not a module depends_on: depends_on defers the
# module's data sources whenever Cilium changes, which made Terraform replace the node
# role's policy attachments and leave the role with no policies.
resource "terraform_data" "cilium_ready" {
  input      = module.eks_cluster.cluster_name
  depends_on = [helm_release.cilium]
}

module "core_nodes" {
  # checkov:skip=CKV_TF_1: registry module, pinned to an exact version (registry sources can't use a commit hash)
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "20.37.2"

  name            = "core_nodes"
  cluster_name    = terraform_data.cilium_ready.output
  cluster_version = module.eks_cluster.cluster_version
  subnet_ids      = module.vpc.private_subnets

  # Only the module's minimal node security group: also attaching the cluster
  # primary SG (broad access) gives nodes two SGs tagged kubernetes.io/cluster/<name>,
  # which the AWS Load Balancer Controller rejects ("expected exactly one securityGroup")
  vpc_security_group_ids = [module.eks_cluster.node_security_group_id]
  cluster_service_cidr   = module.eks_cluster.cluster_service_cidr

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["m7i-flex.large"]

  min_size     = 2
  max_size     = 4
  desired_size = 2
}
