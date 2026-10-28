terraform {
  cloud {
    organization = "cymbal-bank-org"

    workspaces {
      name = "cymbal-bank-prod"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.8.0"
}
