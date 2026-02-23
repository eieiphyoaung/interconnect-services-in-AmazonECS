# Public ECR Repository for Counting Service
resource "aws_ecrpublic_repository" "counting_service" {
  provider        = aws.ecr_public
  repository_name = var.counting_service_repository_name
  force_destroy   = true

  catalog_data {
    about_text        = "Counting service for demo - Multi-platform support (ARM64 for Mac, AMD64 for Linux)"
    architectures     = ["x86-64", "ARM 64"]
    description       = "Counting service demo application with multi-platform support"
    operating_systems = ["Linux", "macOS"]
  }

  tags = {
    Name        = "counting-service"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# Public ECR Repository for Dashboard Service
resource "aws_ecrpublic_repository" "dashboard_service" {
  provider        = aws.ecr_public
  repository_name = var.dashboard_service_repository_name
  force_destroy   = true

  catalog_data {
    about_text        = "Dashboard service for demo - Multi-platform support (ARM64 for Mac, AMD64 for Linux)"
    architectures     = ["x86-64", "ARM 64"]
    description       = "Dashboard service demo application with multi-platform support"
    operating_systems = ["Linux", "macOS"]
  }

  tags = {
    Name        = "dashboard-service"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# Automatically build and push Docker images to ECR
resource "null_resource" "build_and_push_images" {
  # Trigger rebuild when ECR repositories change or when Dockerfiles change
  triggers = {
    counting_repository_url  = aws_ecrpublic_repository.counting_service.repository_uri
    dashboard_repository_url = aws_ecrpublic_repository.dashboard_service.repository_uri
    # Force rebuild if Dockerfiles change
    counting_dockerfile  = filemd5("${path.module}/counting/Dockerfile")
    dashboard_dockerfile = filemd5("${path.module}/dashboard/Dockerfile")
    # Force rebuild if service files change
    counting_service  = filemd5("${path.module}/counting/counting-service")
    dashboard_service = filemd5("${path.module}/dashboard/dashboard-service")
  }

  # Run the build and push script
  provisioner "local-exec" {
    command     = "./push-to-ecr.sh"
    working_dir = path.module
    
    environment = {
      TF_VAR_COUNTING_REPO_URL  = aws_ecrpublic_repository.counting_service.repository_uri
      TF_VAR_DASHBOARD_REPO_URL = aws_ecrpublic_repository.dashboard_service.repository_uri
      TF_VAR_IMAGE_TAG          = var.image_tag
      TF_VAR_AWS_PROFILE        = var.aws_profile
    }
  }

  # Ensure ECR repositories are created before building
  depends_on = [
    aws_ecrpublic_repository.counting_service,
    aws_ecrpublic_repository.dashboard_service
  ]
}
