output "state_bucket_name" {
  description = "S3 bucket for the main Terraform state's state and native .tflock lockfiles."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "Region containing the Terraform state bucket."
  value       = var.aws_region
}

output "main_state_key" {
  description = "Recommended object key for the main Magnolia infrastructure state."
  value       = "magnolia/terraform.tfstate"
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider used by the CI roles."
  value       = local.github_oidc_provider_arn
}

output "github_plan_role_arn" {
  description = "IAM role ARN for Terraform plans from pull requests."
  value       = aws_iam_role.github_plan.arn
}

output "github_deploy_role_arn" {
  description = "Administrator IAM role ARN for Terraform applies from main."
  value       = aws_iam_role.github_deploy.arn
}
