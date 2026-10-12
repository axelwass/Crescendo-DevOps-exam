variable "aws_region" {
  description = "AWS region for the Magnolia deployment."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Short prefix used to name AWS resources."
  type        = string
  default     = "crescendo-magnolia"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.name))
    error_message = "name must be 2-20 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "vpc_cidr" {
  description = "IPv4 /16 range for the deployment VPC. Subnets are carved as /24s."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(regex("/16$", var.vpc_cidr)) && can(cidrsubnet(var.vpc_cidr, 8, 11))
    error_message = "vpc_cidr must be a valid IPv4 /16 network."
  }
}

variable "image_tag" {
  description = "Existing Magnolia image tag in the ECR repository."
  type        = string
  default     = "latest"
}

variable "db_instance_class" {
  description = "RDS PostgreSQL instance class. Increase for production workloads."
  type        = string
  default     = "db.t4g.small"
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_days >= 1 && var.db_backup_retention_days <= 35
    error_message = "db_backup_retention_days must be between 1 and 35."
  }
}

variable "magnolia_cpu" {
  description = "Fargate task CPU units. 1024 is one vCPU."
  type        = number
  default     = 1024
}

variable "magnolia_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 4096
}

variable "magnolia_desired_count" {
  description = "ECS service task count. Keep at one: this Magnolia Jackrabbit configuration is not clustered."
  type        = number
  default     = 1

  validation {
    condition     = var.magnolia_desired_count == 1
    error_message = "This single-node Jackrabbit configuration supports exactly one Magnolia task."
  }
}

variable "cloudfront_price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}
