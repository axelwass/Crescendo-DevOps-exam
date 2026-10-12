data "aws_iam_openid_connect_provider" "github" {
  count = var.github_oidc_provider_arn == null ? 0 : 1
  arn   = var.github_oidc_provider_arn
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_oidc_provider_arn == null ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "Terraform bootstrap"
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "github-actions-terraform-plan"
  description          = "Read-only Terraform plan role for trusted pull requests from ${var.github_repository}."
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${local.github_oidc_subject}:pull_request"
        }
      }
    }]
  })

  tags = {
    Name      = "github-actions-terraform-plan"
    ManagedBy = "Terraform bootstrap"
  }
}

resource "aws_iam_role_policy_attachment" "github_plan_read_only" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "github_plan_state_access" {
  name = "terraform-state-access"
  role = aws_iam_role.github_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.terraform_state.arn}/magnolia/terraform.tfstate"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/magnolia/terraform.tfstate.tflock"
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_plan_secret_access" {
  name = "terraform-application-secret-read"
  role = aws_iam_role.github_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.application_name_prefix}/application-*"
    }]
  })
}

resource "aws_iam_role" "github_deploy" {
  name                 = "github-actions-terraform-deploy"
  description          = "Terraform deployment role for merges to main in ${var.github_repository}."
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${local.github_oidc_subject}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = {
    Name      = "github-actions-terraform-deploy"
    ManagedBy = "Terraform bootstrap"
  }
}

resource "aws_iam_role_policy_attachment" "github_deploy_administrator" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
