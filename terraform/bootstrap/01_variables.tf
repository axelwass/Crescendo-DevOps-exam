variable "aws_region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_prefix" {
  description = "Prefix for the globally unique Terraform state bucket name."
  type        = string
  default     = "crescendo-magnolia-tfstate"

  validation {
    condition     = length(var.state_bucket_prefix) <= 30 && can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.state_bucket_prefix))
    error_message = "state_bucket_prefix must be at most 30 lowercase letters, numbers, or hyphens and start and end with a letter or number."
  }
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to assume the CI roles, for example axelwass/Crescendo-DevOps-exam."
  type        = string
  default     = "axelwass/Crescendo-DevOps-exam"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must have the form owner/repository."
  }
}

variable "github_oidc_provider_arn" {
  description = "ARN of an existing GitHub Actions OIDC provider. Leave null to create it in this bootstrap."
  type        = string
  default     = null
  nullable    = true
}

variable "application_name_prefix" {
  description = "Main Terraform name prefix, used to scope CI plan access to the generated application secret."
  type        = string
  default     = "crescendo-magnolia"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.application_name_prefix))
    error_message = "application_name_prefix must be 2-20 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

locals {
  state_bucket_name        = "${var.state_bucket_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  github_oidc_provider_arn = var.github_oidc_provider_arn != null ? data.aws_iam_openid_connect_provider.github[0].arn : aws_iam_openid_connect_provider.github[0].arn
}
