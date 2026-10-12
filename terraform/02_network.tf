locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  subnets = {
    public_a = {
      cidr              = cidrsubnet(var.vpc_cidr, 8, 0)
      availability_zone = local.azs[0]
      public            = true
    }
    public_b = {
      cidr              = cidrsubnet(var.vpc_cidr, 8, 1)
      availability_zone = local.azs[1]
      public            = true
    }
    private_a = {
      cidr              = cidrsubnet(var.vpc_cidr, 8, 10)
      availability_zone = local.azs[0]
      public            = false
    }
    private_b = {
      cidr              = cidrsubnet(var.vpc_cidr, 8, 11)
      availability_zone = local.azs[1]
      public            = false
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_subnet" "main" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.public

  tags = {
    Name = "${var.name}-${each.key}"
    Tier = each.value.public ? "public" : "private"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.main["public_a"].id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.name}-nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = {
    public_a = aws_subnet.main["public_a"].id
    public_b = aws_subnet.main["public_b"].id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = {
    private_a = aws_subnet.main["private_a"].id
    private_b = aws_subnet.main["private_b"].id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public HTTP ingress for the CloudFront origin."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "CloudFront origin requests; ALB listener also requires the distribution secret header."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow ALB outbound connections; target security group limits access to port 8080."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs"
  description = "Private Magnolia Fargate tasks."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Magnolia traffic from the ALB."
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Outbound traffic for image pulls, secrets, and updates via NAT."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-ecs"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "PostgreSQL accessible only from Magnolia tasks."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Magnolia tasks."
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "${var.name}-rds"
  }
}

resource "aws_security_group" "efs" {
  name        = "${var.name}-efs"
  description = "NFS access for Magnolia tasks."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from Magnolia tasks."
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "${var.name}-efs"
  }
}
