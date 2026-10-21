# GitHub Actions OIDC provider: lets the pipelines assume AWS roles without static keys
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # GitHub sends the immutable subject format: repo:OWNER@OWNER_ID/REPO@REPO_ID:...
  infra_repo_sub = "repo:${var.github_owner}@${var.github_owner_id}/feedback-infra@${var.github_repo_ids["feedback-infra"]}"
}

# Trust policy shared by the infra pipeline roles; only the subject changes
data "aws_iam_policy_document" "infra_pipeline_trust" {
  for_each = {
    plan  = "${local.infra_repo_sub}:pull_request"
    apply = "${local.infra_repo_sub}:ref:refs/heads/main"
  }

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

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value]
    }
  }
}

# Pull requests (ci.yml): terraform plan only, read-only access
resource "aws_iam_role" "infra_plan" {
  name               = "${var.project}-github-infra-plan"
  assume_role_policy = data.aws_iam_policy_document.infra_pipeline_trust["plan"].json
}

resource "aws_iam_role_policy_attachment" "infra_plan_readonly" {
  role       = aws_iam_role.infra_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Merge to main (deploy.yml): terraform apply, limited to the services this project uses
resource "aws_iam_role" "infra_apply" {
  name               = "${var.project}-github-infra-apply"
  assume_role_policy = data.aws_iam_policy_document.infra_pipeline_trust["apply"].json
}

data "aws_iam_policy_document" "infra_apply" {
  statement {
    sid = "ProjectServices"
    actions = [
      "apigateway:*",
      "cloudwatch:*",
      "cognito-idp:*",
      "dynamodb:*",
      "events:*",
      "lambda:*",
      "logs:*",
      "scheduler:*",
      "ses:*",
      "sns:*",
      "sqs:*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "IamRead"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  statement {
    sid     = "IamProjectRolesOnly"
    actions = ["iam:*"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-*",
      "arn:aws:iam::${local.account_id}:policy/${var.project}-*",
      aws_iam_openid_connect_provider.github.arn,
    ]
  }

  # DynamoDB encryption with the AWS managed key aws/dynamodb
  statement {
    sid       = "KmsForDynamoDb"
    actions   = ["kms:CreateGrant", "kms:DescribeKey", "kms:ListAliases"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "infra_apply" {
  name   = "${var.project}-github-infra-apply"
  role   = aws_iam_role.infra_apply.id
  policy = data.aws_iam_policy_document.infra_apply.json
}
