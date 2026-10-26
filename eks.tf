module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                  = "cymbal-bank-mesh"
  cluster_version               = "1.36"
  bootstrap_self_managed_addons = false



  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true


  node_security_group_tags = {
    "karpenter.sh/discovery" = "cymbal-bank-mesh"
  }

  # Node group (nodes.tf) and add-ons (eks-addons.tf) live outside this module
  # so they can be ordered after Cilium: control plane -> Cilium -> nodes -> add-ons

  access_entries = {
    local_admin = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    # Destroy workflow: cleans up controller-created resources before terraform destroy
    # (role created by bootstrap/main.tf)
    github_cleanup = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-cymbal-bank"

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
