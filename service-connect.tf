# ECS Service Connect Configuration

# Service Connect Namespace (replaces Cloud Map for service discovery)
resource "aws_service_discovery_http_namespace" "service_connect" {
  name        = var.service_connect_namespace
  description = "ECS Service Connect namespace for microservices communication"

  tags = {
    Name        = var.service_connect_namespace
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Log Group for Service Connect
resource "aws_cloudwatch_log_group" "service_connect" {
  name              = "/ecs/${var.cluster_name}/service-connect"
  retention_in_days = 7

  tags = {
    Name        = "service-connect-logs"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# KMS Key for Service Connect TLS (optional - only if TLS is enabled)
resource "aws_kms_key" "service_connect" {
  count = var.enable_service_connect_tls ? 1 : 0

  description             = "KMS key for ECS Service Connect TLS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Service Connect to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.service_connect_tls[0].arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyPair",
          "kms:GenerateDataKeyPairWithoutPlaintext",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-service-connect-kms"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "service_connect" {
  count = var.enable_service_connect_tls ? 1 : 0

  name          = "alias/${var.cluster_name}-service-connect"
  target_key_id = aws_kms_key.service_connect[0].key_id
}

# IAM Role for Service Connect TLS
resource "aws_iam_role" "service_connect_tls" {
  count = var.enable_service_connect_tls ? 1 : 0

  name = "${var.cluster_name}-service-connect-tls-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com",
            "ecs.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-service-connect-tls-role"
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

# IAM Policy for Service Connect TLS
resource "aws_iam_role_policy" "service_connect_tls" {
  count = var.enable_service_connect_tls ? 1 : 0

  name = "${var.cluster_name}-service-connect-tls-policy"
  role = aws_iam_role.service_connect_tls[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm-pca:GetCertificate",
          "acm-pca:GetCertificateAuthorityCertificate",
          "acm-pca:DescribeCertificateAuthority",
          "acm-pca:IssueCertificate"
        ]
        Resource = var.aws_pca_authority_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyPair",
          "kms:GenerateDataKeyPairWithoutPlaintext",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.service_connect[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:RotateSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:ecs-sc!*"
      }
    ]
  })
}
