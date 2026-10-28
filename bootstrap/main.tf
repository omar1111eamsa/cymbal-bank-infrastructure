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
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.11.0"
}

provider "aws" {
  region = "eu-west-1"
}

provider "tfe" {
  organization = local.org
}

# Reads GITHUB_TOKEN from the environment (export GITHUB_TOKEN=$(gh auth token))
provider "github" {
  owner = local.github_owner
}

locals {
  org          = "cymbal-bank-org"
  github_owner = "omar1111eamsa"
  github_repo  = "cymbal-bank-infrastructure"

  workspaces = {
    prod       = "cymbal-bank-prod"       # ephemeral: destroyed at the end of each session
    persistent = "cymbal-bank-persistent" # DNS, certificate, secrets: never destroyed
  }
}

# =====================================================================
# HCP Terraform -> AWS (OIDC, no access keys)
# =====================================================================
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
      values = [
        for ws in values(local.workspaces) :
        "organization:${local.org}:project:*:workspace:${ws}:run_phase:*"
      ]
    }
  }
}

resource "aws_iam_role" "hcp_terraform" {
  name               = "hcp-terraform-cymbal-bank"
  assume_role_policy = data.aws_iam_policy_document.hcp_trust.json
}

# Least privilege instead of AdministratorAccess:
# PowerUserAccess (every service except IAM/Organizations) + IAM scoped to this project.
# Whoever can create IAM roles can become admin, so IAM is limited to resources
# tagged Project=cymbal-bank (the stacks' default_tags) and escalation paths are denied.
resource "aws_iam_role_policy_attachment" "hcp_terraform_power_user" {
  role       = aws_iam_role.hcp_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "hcp_terraform_iam" {
  # checkov:skip=CKV_AWS_356: iam:Get*/List* are read-only; writes below are tag-scoped
  statement {
    sid       = "ReadIam"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  # Terraform sends the default_tags with the create call
  statement {
    sid       = "CreateTagged"
    actions   = ["iam:CreateRole", "iam:CreatePolicy", "iam:CreateInstanceProfile", "iam:CreateOpenIDConnectProvider", "iam:TagRole", "iam:TagPolicy", "iam:TagInstanceProfile", "iam:TagOpenIDConnectProvider"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = ["cymbal-bank"]
    }
  }

  statement {
    sid = "ManageTagged"
    actions = [
      "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:DeletePolicy",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:UpdateOpenIDConnectProviderThumbprint", "iam:DeleteOpenIDConnectProvider",
      "iam:TagRole", "iam:TagPolicy", "iam:TagInstanceProfile", "iam:TagOpenIDConnectProvider",
      "iam:UntagRole", "iam:UntagPolicy", "iam:UntagInstanceProfile", "iam:UntagOpenIDConnectProvider",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["cymbal-bank"]
    }
  }

  # PassRole isn't matched by role tags: scope it by the receiving service instead
  # (cluster and node group roles to EKS, controller roles to EKS Pod Identity)
  statement {
    sid       = "PassRoleToEks"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com", "pods.eks.amazonaws.com"]
    }
  }

  # EKS access entries for node roles pass the role without iam:PassedToService:
  # allow only the node roles, by name
  statement {
    sid     = "PassNodeRoles"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterNodeRole-cymbal-bank",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/core_nodes-eks-node-group-*",
    ]
  }

  # Escalation paths: never change the CI roles (reading stays allowed: the EKS
  # module reads the caller's own role), never hand out admin
  statement {
    sid         = "DenyCiRoles"
    effect      = "Deny"
    not_actions = ["iam:Get*", "iam:List*"]
    resources = [
      aws_iam_role.hcp_terraform.arn,
      aws_iam_role.github_cleanup.arn,
    ]
  }

  statement {
    sid       = "DenyAdminPolicies"
    effect    = "Deny"
    actions   = ["iam:AttachRolePolicy"]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values = [
        "arn:aws:iam::aws:policy/AdministratorAccess",
        "arn:aws:iam::aws:policy/IAMFullAccess",
        "arn:aws:iam::aws:policy/PowerUserAccess",
      ]
    }
  }
}

resource "aws_iam_role_policy" "hcp_terraform_iam" {
  name   = "iam-project-scoped"
  role   = aws_iam_role.hcp_terraform.id
  policy = data.aws_iam_policy_document.hcp_terraform_iam.json
}

# =====================================================================
# HCP workspaces: both use the role above
# =====================================================================
import {
  to = tfe_workspace.prod
  id = "${local.org}/${local.workspaces.prod}"
}

resource "tfe_workspace" "prod" {
  name         = local.workspaces.prod
  organization = local.org
}

resource "tfe_workspace" "persistent" {
  name         = local.workspaces.persistent
  organization = local.org
}

locals {
  workspace_ids = {
    prod       = tfe_workspace.prod.id
    persistent = tfe_workspace.persistent.id
  }
}

resource "tfe_variable" "aws_provider_auth" {
  for_each = local.workspace_ids

  workspace_id = each.value
  category     = "env"
  key          = "TFC_AWS_PROVIDER_AUTH"
  value        = "true"
}

resource "tfe_variable" "aws_run_role_arn" {
  for_each = local.workspace_ids

  workspace_id = each.value
  category     = "env"
  key          = "TFC_AWS_RUN_ROLE_ARN"
  value        = aws_iam_role.hcp_terraform.arn
}

# Existing single-workspace variables become the "prod" entry of the maps above
moved {
  from = tfe_variable.aws_provider_auth
  to   = tfe_variable.aws_provider_auth["prod"]
}

moved {
  from = tfe_variable.aws_run_role_arn
  to   = tfe_variable.aws_run_role_arn["prod"]
}



# =====================================================================
# GitHub Actions -> AWS (OIDC): used by the destroy workflow to clean up
# controller-created resources (ALB, EBS volumes) before terraform destroy
# =====================================================================
# GitHub sends "immutable" subjects with numeric IDs (repo:<owner>@<owner_id>/<repo>@<repo_id>:...):
# a renamed or re-created repo with the same name can't inherit this trust
data "github_user" "owner" {
  username = local.github_owner
}

data "github_repository" "infra" {
  full_name = "${local.github_owner}/${local.github_repo}"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only workflows running on main of this repository
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.github_owner}@${data.github_user.owner.id}/${local.github_repo}@${data.github_repository.infra.repo_id}:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "github_cleanup" {
  name               = "github-actions-cymbal-bank"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_cleanup" {
  # checkov:skip=CKV_AWS_356: ec2:DescribeVolumes only supports "*"; DeleteVolume is limited by the CSI tag condition
  statement {
    sid       = "FindCluster"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:eu-west-1:${data.aws_caller_identity.current.account_id}:cluster/cymbal-bank-mesh"]
  }

  statement {
    sid       = "FindVolumes"
    actions   = ["ec2:DescribeVolumes"]
    resources = ["*"]
  }

  # Only volumes created by the EBS CSI driver
  statement {
    sid       = "DeleteCsiVolumes"
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "github_cleanup" {
  name   = "destroy-cleanup"
  role   = aws_iam_role.github_cleanup.id
  policy = data.aws_iam_policy_document.github_cleanup.json
}

# The workflow reads the role ARN from a repository variable (no account ID in Git)
resource "github_actions_variable" "cleanup_role_arn" {
  repository    = local.github_repo
  variable_name = "AWS_CLEANUP_ROLE_ARN"
  value         = aws_iam_role.github_cleanup.arn
}



# main is protected: changes only through a PR whose checks pass
resource "github_repository_ruleset" "main" {
  name        = "protect-main"
  repository  = data.github_repository.infra.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true # no deleting main
    non_fast_forward = true # no force-push (history can't be rewritten)

    pull_request {
      required_approving_review_count = 0 # solo project: you can't approve your own PR
    }

    required_status_checks {
      strict_required_status_checks_policy = true # branch must be up to date with main

      required_check { context = "Terraform (fmt, validate, tflint) (.)" }
      required_check { context = "Terraform (fmt, validate, tflint) (persistent)" }
      required_check { context = "Terraform (fmt, validate, tflint) (bootstrap)" }
      required_check { context = "Checkov (security misconfigurations)" }
      required_check { context = "Kubeconform (gitOps manifests)" }
      required_check { context = "Persistent layer (DNS, certificate, secrets)" }
      required_check { context = "Environment (VPC, EKS, platform)" }
    }
  }
}
