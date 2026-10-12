output "ecr_repository_url" {
  description = "ECR repository URL used by the Magnolia image build and push workflows."
  value       = aws_ecr_repository.magnolia.repository_url
}

output "cloudfront_url" {
  description = "Public CloudFront URL for Magnolia. It is available after the distribution deploys."
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID, used to invalidate cached content after deployment."
  value       = aws_cloudfront_distribution.main.id
}

output "rds_address" {
  description = "Private PostgreSQL endpoint."
  value       = aws_db_instance.magnolia.address
}

output "application_secret_arn" {
  description = "Secrets Manager secret containing the database and initial Magnolia admin passwords."
  value       = aws_secretsmanager_secret.application.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster containing the Magnolia service."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service running Magnolia."
  value       = aws_ecs_service.magnolia.name
}
