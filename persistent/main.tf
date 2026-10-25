# Persistent layer: survives every destroy of the ephemeral environment.
# Holds what is slow to recreate (DNS delegation, validated certificate)
# or must keep its value (secrets). Costs ~$1/month.

terraform {
  cloud {
    organization = "cymbal-bank-org"

    workspaces {
      name = "cymbal-bank-persistent"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }

  required_version = ">= 1.8.0"
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Environment = "prod"
      Project     = "cymbal-bank"
      ManagedBy   = "terraform"
      Layer       = "persistent"
    }
  }
}

