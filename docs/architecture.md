# Architecture

Back to the [README](../README.md).

![Architecture diagram](diagams/network-architecture.drawio.png)

Editable source: [network-architecture.drawio](diagams/network-architecture.drawio).

## Request flow

Browser → CloudFront (HTTPS) → ALB (HTTP :80) → Magnolia on ECS Fargate (:8080). Magnolia stores content in RDS PostgreSQL and repository files in EFS.

## Deviations from the brief

- **ECS Fargate instead of EC2:** nothing to patch, and the same container image runs locally.
- **No Nginx:** the ALB already handles routing and health checks.
- **RDS and EFS:** the Magnolia state survives task replacement.

## Network

- Dedicated VPC with 2 public and 2 private subnets in two AZs, an Internet Gateway, one NAT Gateway, and route tables.
- The ALB is public; ECS, RDS and EFS are private.
- Private subnets reach ECR, Secrets Manager and CloudWatch through the NAT.
- The ALB returns `403` unless the request carries a secret header that CloudFront adds.

## CloudFront caching

- **Cached:** `/.resources/*` and `/.imaging/*` (1 hour default, 1 day max).
- **Not cached:** everything else, including pages and the admin.
- Content published in Magnolia does not invalidate the cache; deployments invalidate `/*`.

## Terraform state

State is in an encrypted, versioned S3 bucket with native lockfiles. A separate `terraform/bootstrap` config creates the bucket and the GitHub roles. Its own state is local, so keep it private and backed up. State holds generated credentials, so treat it as a secret.

## CI/CD and IAM

GitHub authenticates to AWS with OIDC, with no stored keys. Bootstrap creates two roles:

- **Plan role:** read-only, trusted for pull requests from this repository.
- **Deploy role:** `AdministratorAccess`, trusted for pushes to `main` only. This is a shortcut for the interview, so protect `main`.

Pull requests run `terraform fmt`, `validate` and `plan` ([validate.yml](../.github/workflows/validate.yml)). A push to `main` runs [deploy.yml](../.github/workflows/deploy.yml):

1. Apply Terraform.
2. Build and push the image (`latest`).
3. Restart ECS and wait until it is stable.
4. Invalidate CloudFront.

The ECS service does not wait for a healthy task during apply, because the image does not exist on the first run.

Bootstrap options:

- If your account already has the GitHub OIDC provider, pass its ARN as `github_oidc_provider_arn`.
- For another repository, set `github_repository`, `github_owner_id` and `github_repository_id`.
- If you rename the stack, set `application_name_prefix` to match.

## Limitations

- **One Magnolia task:** the Jackrabbit repository is not clustered.
- **Not highly available:** one NAT Gateway and a single-AZ RDS instance, to keep costs down.
- **HTTP to the ALB:** CloudFront to ALB is plain HTTP because there is no custom domain or certificate.
- **Mutable `latest` image tag:** ECR keeps the last ten images.
- **Destroy is destructive:** RDS is deleted without a final snapshot, and EFS is removed.
