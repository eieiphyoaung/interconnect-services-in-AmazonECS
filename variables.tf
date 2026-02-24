variable "aws_region" {
  description = "AWS region for general resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "ecr_public_region" {
  description = "AWS region for public ECR (must be us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "master-programmatic-admin"
}

variable "counting_service_repository_name" {
  description = "Name of the ECR repository for counting service"
  type        = string
  default     = "counting-service"
}

variable "dashboard_service_repository_name" {
  description = "Name of the ECR repository for dashboard service"
  type        = string
  default     = "dashboard-service"
}

variable "image_tag" {
  description = "Tag for the Docker images"
  type        = string
  default     = "latest"
}

variable "local_counting_image" {
  description = "Local Docker image name for counting service (e.g., ei2000/counting:latest)"
  type        = string
  default     = ""
}

variable "local_dashboard_image" {
  description = "Local Docker image name for dashboard service (e.g., ei2000/dashboard:latest)"
  type        = string
  default     = ""
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

# ECS Configuration
variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "demo-cluster"
}

variable "service_connect_namespace" {
  description = "Service Connect namespace for ECS service mesh"
  type        = string
  default     = "demo-services"
}

variable "enable_service_connect_tls" {
  description = "Enable TLS for Service Connect (requires AWS Private CA)"
  type        = bool
  default     = false
}

variable "aws_pca_authority_arn" {
  description = "ARN of AWS Private Certificate Authority for Service Connect TLS (leave empty to disable TLS)"
  type        = string
  default     = ""
}

variable "cpu_architecture" {
  description = "CPU architecture for ECS tasks (X86_64 or ARM64)"
  type        = string
  default     = "ARM64"  # Changed to ARM64 to match the Docker image architecture
}

# Counting Service Configuration
variable "counting_service_cpu" {
  description = "CPU units for counting service (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "counting_service_memory" {
  description = "Memory for counting service (MB)"
  type        = string
  default     = "512"
}

variable "counting_service_desired_count" {
  description = "Desired number of counting service tasks"
  type        = number
  default     = 1
}

# Dashboard Service Configuration
variable "dashboard_service_cpu" {
  description = "CPU units for dashboard service (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "dashboard_service_memory" {
  description = "Memory for dashboard service (MB)"
  type        = string
  default     = "512"
}

variable "dashboard_service_desired_count" {
  description = "Desired number of dashboard service tasks"
  type        = number
  default     = 1
}
