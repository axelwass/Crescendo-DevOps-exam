resource "aws_cloudwatch_log_group" "magnolia" {
  name              = "/ecs/${var.name}/magnolia"
  retention_in_days = 14

  tags = {
    Name = "${var.name}-magnolia"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.name}-cluster"
  }
}

resource "aws_iam_role" "task_execution" {
  name = "${var.name}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "read_application_secret" {
  name = "${var.name}-read-application-secret"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.application.arn
    }]
  })
}

resource "aws_iam_role" "task" {
  name = "${var.name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "efs_access" {
  name = "${var.name}-efs-access"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ]
      Resource = aws_efs_file_system.magnolia.arn
      Condition = {
        StringEquals = {
          "elasticfilesystem:AccessPointArn" = aws_efs_access_point.magnolia.arn
        }
        Bool = {
          "elasticfilesystem:AccessedViaMountTarget" = "true"
        }
      }
    }]
  })
}

resource "aws_ecs_task_definition" "magnolia" {
  family                   = "${var.name}-magnolia"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.magnolia_cpu
  memory                   = var.magnolia_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  ephemeral_storage {
    size_in_gib = 30
  }

  volume {
    name = "magnolia-repository"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.magnolia.id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.magnolia.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([{
    name      = "magnolia"
    image     = "${aws_ecr_repository.magnolia.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "DB_URL"
        value = "jdbc:postgresql://${aws_db_instance.magnolia.address}:5432/magnolia"
      },
      {
        name  = "DB_USER"
        value = aws_db_instance.magnolia.username
      }
    ]

    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.application.arn}:db_password::"
      },
      {
        name      = "MAGNOLIA_SUPERUSER_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.application.arn}:magnolia_superuser_password::"
      }
    ]

    mountPoints = [{
      sourceVolume  = "magnolia-repository"
      containerPath = "/usr/local/tomcat/webapps/ROOT/repositories"
      readOnly      = false
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.magnolia.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "magnolia"
      }
    }
  }])

  tags = {
    Name = "${var.name}-magnolia"
  }
}

resource "aws_ecs_service" "magnolia" {
  name                               = "${var.name}-magnolia"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.magnolia.arn
  desired_count                      = var.magnolia_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  health_check_grace_period_seconds  = 600
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  wait_for_steady_state              = false

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [aws_subnet.main["private_a"].id, aws_subnet.main["private_b"].id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.magnolia.arn
    container_name   = "magnolia"
    container_port   = 8080
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution,
    aws_iam_role_policy.read_application_secret,
    aws_iam_role_policy.efs_access,
    aws_secretsmanager_secret_version.application,
    aws_lb_listener_rule.cloudfront,
    aws_efs_mount_target.private
  ]

  tags = {
    Name = "${var.name}-magnolia"
  }
}
