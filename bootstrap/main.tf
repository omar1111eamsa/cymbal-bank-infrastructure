terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.60"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "tfe" {
  organization = local.org
}

locals {
  org       = "cymbal-bank-org"
  workspace = "cymbal-bank-prod"
}

# --- AWS side: trust HCP Terraform, no access keys ---
resource "aws_iam_openid_connect_provider" "hcp_terraform" {
  url            = "https://app.terraform.io"
  client_id_list = ["aws.workload.identity"]
}

data "aws_iam_policy_document" "hcp_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.hcp_terraform.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "app.terraform.io:aud"
      values   = ["aws.workload.identity"]
    }

    condition {
      test     = "StringLike"
      variable = "app.terraform.io:sub"
      values   = ["organization:${local.org}:project:*:workspace:${local.workspace}:run_phase:*"]
    }
  }
}

resource "aws_iam_role" "hcp_terraform" {
  name               = "hcp-terraform-cymbal-bank"
  assume_role_policy = data.aws_iam_policy_document.hcp_trust.json
}

resource "aws_iam_role_policy_attachment" "hcp_terraform_admin" {
  role       = aws_iam_role.hcp_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- HCP side: the workspace uses that role ---
import {
  to = tfe_workspace.prod
  id = "${local.org}/${local.workspace}"
}

resource "tfe_workspace" "prod" {
  name         = local.workspace
  organization = local.org
}

resource "tfe_variable" "aws_provider_auth" {
  workspace_id = tfe_workspace.prod.id
  category     = "env"
  key          = "TFC_AWS_PROVIDER_AUTH"
  value        = "true"
}

resource "tfe_variable" "aws_run_role_arn" {
  workspace_id = tfe_workspace.prod.id
  category     = "env"
  key          = "TFC_AWS_RUN_ROLE_ARN"
  value        = aws_iam_role.hcp_terraform.arn
}
