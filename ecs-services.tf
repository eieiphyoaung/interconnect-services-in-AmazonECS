# ECS Services with Service Connect (replaces Cloud Map Service Discovery)

# Security Group for Dashboard Service (Public)
resource "aws_security_group" "dashboard" {
  name        = "${var.cluster_name}-dashboard-sg"
  description = "Security group for dashboard service with Service Connect"
  vpc_id      = aws_vpc.main.id

  # Allow dashboard access from internet
  ingress {
    from_port   = 9002
    to_port     = 9002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow dashboard access from internet"
  }

  # Allow all traffic within the same security group (for Service Connect proxy)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within dashboard SG for Service Connect"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.cluster_name}-dashboard-sg"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# Security Group for Counting Service (Private)
resource "aws_security_group" "counting" {
  name        = "${var.cluster_name}-counting-sg"
  description = "Security group for counting service with Service Connect"
  vpc_id      = aws_vpc.main.id

  # Allow application port from dashboard
  ingress {
    from_port       = 9003
    to_port         = 9003
    protocol        = "tcp"
    security_groups = [aws_security_group.dashboard.id]
    description     = "Allow counting service port from dashboard SG"
  }

  # Allow all traffic within the same security group (for Service Connect proxy)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within counting SG for Service Connect"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.cluster_name}-counting-sg"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# ECS Service for Counting (Private Subnet) with Service Connect
resource "aws_ecs_service" "counting" {
  name            = "counting-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.counting.arn
  desired_count   = var.counting_service_desired_count
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.counting.id]
    assign_public_ip = false
  }

  # Service Connect Configuration
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_connect.arn

    service {
      port_name      = "counting"
      discovery_name = "counting"

      client_alias {
        port     = 9003
        dns_name = "counting"
      }

      # Enable TLS if configured
      dynamic "tls" {
        for_each = var.enable_service_connect_tls && var.aws_pca_authority_arn != "" ? [1] : []
        content {
          issuer_cert_authority {
            aws_pca_authority_arn = var.aws_pca_authority_arn
          }

          kms_key = aws_kms_key.service_connect[0].arn

          role_arn = aws_iam_role.service_connect_tls[0].arn
        }
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service_connect.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "counting"
      }
    }
  }

  tags = {
    Name        = "counting-service"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# ECS Service for Dashboard (Public Subnet) with Service Connect
resource "aws_ecs_service" "dashboard" {
  name            = "dashboard-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.dashboard.arn
  desired_count   = var.dashboard_service_desired_count
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.dashboard.id]
    assign_public_ip = true
  }

  # Service Connect Configuration (client and server mode)
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_connect.arn

    service {
      port_name      = "dashboard"
      discovery_name = "dashboard"

      client_alias {
        port     = 9002
        dns_name = "dashboard"
      }

      # Enable TLS if configured
      dynamic "tls" {
        for_each = var.enable_service_connect_tls && var.aws_pca_authority_arn != "" ? [1] : []
        content {
          issuer_cert_authority {
            aws_pca_authority_arn = var.aws_pca_authority_arn
          }

          kms_key = aws_kms_key.service_connect[0].arn

          role_arn = aws_iam_role.service_connect_tls[0].arn
        }
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service_connect.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "dashboard"
      }
    }
  }

  tags = {
    Name        = "dashboard-service"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}
