# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.service_discovery_namespace
  description = "Service discovery namespace for ECS services"
  vpc         = aws_vpc.main.id

  tags = {
    Name        = var.service_discovery_namespace
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# Service Discovery for Counting Service
resource "aws_service_discovery_service" "counting" {
  name = "counting"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name        = "counting-service-discovery"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# Service Discovery for Dashboard Service
resource "aws_service_discovery_service" "dashboard" {
  name = "dashboard"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name        = "dashboard-service-discovery"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# Security Group for Dashboard Service (Public)
# Created first so counting SG can reference it
resource "aws_security_group" "dashboard" {
  name        = "${var.cluster_name}-dashboard-sg"
  description = "Security group for dashboard service in public subnet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 9002
    to_port     = 9002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow dashboard access from internet"
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
# References dashboard SG for least-privilege access control
resource "aws_security_group" "counting" {
  name        = "${var.cluster_name}-counting-sg"
  description = "Security group for counting service in private subnet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 9003
    to_port         = 9003
    protocol        = "tcp"
    security_groups = [aws_security_group.dashboard.id]
    description     = "Allow counting service port from dashboard SG only"
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

# ECS Service for Counting (Private Subnet)
resource "aws_ecs_service" "counting" {
  name            = "counting-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.counting.arn
  desired_count   = var.counting_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.counting.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.counting.arn
  }

  depends_on = [
    aws_service_discovery_service.counting
  ]

  tags = {
    Name        = "counting-service"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# ECS Service for Dashboard (Public Subnet)
resource "aws_ecs_service" "dashboard" {
  name                   = "dashboard-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.dashboard.arn
  desired_count          = var.dashboard_service_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true  # Enable ECS Exec for debugging

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.dashboard.id]
    assign_public_ip = true  # Dashboard gets public IP for direct access
  }

  service_registries {
    registry_arn = aws_service_discovery_service.dashboard.arn
  }

  depends_on = [
    aws_service_discovery_service.dashboard
  ]

  tags = {
    Name        = "dashboard-service"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}
