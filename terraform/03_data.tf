resource "aws_ecr_repository" "magnolia" {
  name                 = "${var.name}/magnolia"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.name}-magnolia"
  }
}

resource "aws_ecr_lifecycle_policy" "magnolia" {
  repository = aws_ecr_repository.magnolia.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the most recent 10 images."
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "random_password" "database" {
  length  = 32
  special = false
}

resource "random_password" "magnolia_admin" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "application" {
  name                    = "${var.name}/application"
  description             = "Magnolia PostgreSQL and initial superuser credentials."
  recovery_window_in_days = 7

  tags = {
    Name = "${var.name}-application"
  }
}

resource "aws_secretsmanager_secret_version" "application" {
  secret_id = aws_secretsmanager_secret.application.id
  secret_string = jsonencode({
    db_password                 = random_password.database.result
    magnolia_superuser_password = random_password.magnolia_admin.result
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-db"
  subnet_ids = [aws_subnet.main["private_a"].id, aws_subnet.main["private_b"].id]

  tags = {
    Name = "${var.name}-db"
  }
}

resource "aws_db_instance" "magnolia" {
  identifier                          = "${var.name}-db"
  engine                              = "postgres"
  instance_class                      = var.db_instance_class
  allocated_storage                   = 20
  max_allocated_storage               = 50
  storage_type                        = "gp3"
  storage_encrypted                   = true
  db_name                             = "magnolia"
  username                            = "magnolia"
  password                            = random_password.database.result
  port                                = 5432
  db_subnet_group_name                = aws_db_subnet_group.main.name
  vpc_security_group_ids              = [aws_security_group.rds.id]
  publicly_accessible                 = false
  multi_az                            = false
  backup_retention_period             = var.db_backup_retention_days
  auto_minor_version_upgrade          = true
  deletion_protection                 = false
  skip_final_snapshot                 = true
  apply_immediately                   = true
  iam_database_authentication_enabled = false

  tags = {
    Name = "${var.name}-db"
  }
}

resource "aws_efs_file_system" "magnolia" {
  creation_token   = "${var.name}-magnolia"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "${var.name}-magnolia"
  }
}

resource "aws_efs_backup_policy" "magnolia" {
  file_system_id = aws_efs_file_system.magnolia.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_access_point" "magnolia" {
  file_system_id = aws_efs_file_system.magnolia.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/magnolia"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0770"
    }
  }

  tags = {
    Name = "${var.name}-magnolia"
  }
}

resource "aws_efs_mount_target" "private" {
  for_each = {
    private_a = aws_subnet.main["private_a"].id
    private_b = aws_subnet.main["private_b"].id
  }

  file_system_id  = aws_efs_file_system.magnolia.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}
