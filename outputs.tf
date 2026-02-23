# ECR Repository Outputs
output "counting_service_repository_url" {
  description = "Public ECR repository URL for counting service"
  value       = aws_ecrpublic_repository.counting_service.repository_uri
}

output "dashboard_service_repository_url" {
  description = "Public ECR repository URL for dashboard service"
  value       = aws_ecrpublic_repository.dashboard_service.repository_uri
}

# ECS Cluster Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

# Image Tag
output "image_tag" {
  description = "Image tag used for deployments"
  value       = var.image_tag
}

# AWS Configuration
output "aws_region" {
  description = "AWS region for main resources"
  value       = var.aws_region
}

output "aws_profile" {
  description = "AWS CLI profile used"
  value       = var.aws_profile
}

# Service Discovery
output "counting_service_dns" {
  description = "Service discovery DNS for counting service (accessible from within VPC)"
  value       = "counting.${var.service_discovery_namespace}"
}

output "dashboard_service_dns" {
  description = "Service discovery DNS for dashboard service (accessible from within VPC)"
  value       = "dashboard.${var.service_discovery_namespace}"
}

# Dashboard Access
output "dashboard_service_name" {
  description = "Dashboard ECS service name"
  value       = aws_ecs_service.dashboard.name
}

output "dashboard_cluster_name" {
  description = "ECS cluster name for dashboard"
  value       = aws_ecs_cluster.main.name
}

# Dashboard Public IP
output "dashboard_public_ip" {
  description = "Public IP address of the dashboard service"
  value       = data.external.dashboard_ip.result.ip
}

output "dashboard_url" {
  description = "URL to access the dashboard service"
  value       = data.external.dashboard_ip.result.status == "available" ? "http://${data.external.dashboard_ip.result.ip}:9002" : "Dashboard IP not yet available - run 'terraform refresh'"
}
