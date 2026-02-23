# ECS Task Definitions

# Task Definition for Counting Service
resource "aws_ecs_task_definition" "counting" {
  family                   = "counting-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.counting_service_cpu
  memory                   = var.counting_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name      = "counting"
      image     = "${aws_ecrpublic_repository.counting_service.repository_uri}:${var.image_tag}"
      essential = true
      
      portMappings = [
        {
          containerPort = 9003
          hostPort      = 9003
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "9003"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.counting_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9003/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "counting-service-task"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# Task Definition for Dashboard Service
resource "aws_ecs_task_definition" "dashboard" {
  family                   = "dashboard-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.dashboard_service_cpu
  memory                   = var.dashboard_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name      = "dashboard"
      image     = "${aws_ecrpublic_repository.dashboard_service.repository_uri}:${var.image_tag}"
      essential = true
      
      portMappings = [
        {
          containerPort = 9002
          hostPort      = 9002
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "9002"
        },
        {
          name  = "COUNTING_SERVICE_URL"
          value = "http://counting.${var.service_discovery_namespace}:9003"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dashboard_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9002/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])

  tags = {
    Name        = "dashboard-service-task"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}
