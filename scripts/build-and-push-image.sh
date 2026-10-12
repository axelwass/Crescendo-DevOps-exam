#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s IMAGE_TAG\n' "$0" >&2
  exit 2
fi

IMAGE_TAG=$1
AWS_REGION=${AWS_REGION:-us-east-1}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(dirname "$SCRIPT_DIR")
ECR_REPOSITORY_URL=$(terraform -chdir="$REPOSITORY_ROOT/terraform" output -raw ecr_repository_url)
ECR_REGISTRY=${ECR_REPOSITORY_URL%%/*}
ECS_CLUSTER=$(terraform -chdir="$REPOSITORY_ROOT/terraform" output -raw ecs_cluster_name)
ECS_SERVICE=$(terraform -chdir="$REPOSITORY_ROOT/terraform" output -raw ecs_service_name)

aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build \
  --tag "$ECR_REPOSITORY_URL:$IMAGE_TAG" \
  "$REPOSITORY_ROOT/docker"
docker push "$ECR_REPOSITORY_URL:$IMAGE_TAG"

printf 'Image pushed: %s:%s\n' "$ECR_REPOSITORY_URL" "$IMAGE_TAG"
printf 'If terraform/terraform.tfvars already uses this image_tag, restart the service with:\n'
printf '  aws ecs update-service --cluster %s --service %s --force-new-deployment --region %s\n' \
  "$ECS_CLUSTER" "$ECS_SERVICE" "$AWS_REGION"
printf 'Otherwise set image_tag = "%s" in terraform/terraform.tfvars and run terraform apply.\n' "$IMAGE_TAG"
