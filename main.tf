terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Provider for Public ECR (must be us-east-1)
provider "aws" {
  alias   = "ecr_public"
  region  = var.ecr_public_region
  profile = var.aws_profile
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {}
