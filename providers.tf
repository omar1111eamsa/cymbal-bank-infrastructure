provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Environment = "prod"
      Project     = "cymbal-bank"
      ManagedBy   = "terraform"
    }
  }
}

#----------------- this  is for helm

data "aws_eks_cluster" "cluster" {
  name       = module.eks_cluster.cluster_name
  depends_on = [module.eks_cluster]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks_cluster.cluster_name
  depends_on = [module.eks_cluster]
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
