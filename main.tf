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


    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.8.0"
}
