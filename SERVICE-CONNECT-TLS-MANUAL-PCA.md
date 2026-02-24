# ECS Service Connect with TLS using Manual AWS Private CA

## 🎯 Overview

This guide shows how to enable TLS for ECS Service Connect using a **manually created** AWS Private Certificate Authority (PCA).

## 📋 Prerequisites

You'll need to manually create:
1. ✅ AWS Private Certificate Authority (PCA)
2. ✅ The PCA ARN

Terraform will automatically create:
- KMS key for encryption
- IAM role for Service Connect TLS
- Service Connect configuration with TLS

## 🔧 Step 1: Create AWS Private CA (Manual)

### Option A: Using AWS Console

1. Go to **AWS Certificate Manager** → **Private CAs**
2. Click **Create a private CA**
3. Configure:
   - **CA type**: Root CA (or Subordinate if you have a root)
   - **Subject DN**: 
     - Common Name: `demo-services.internal`
     - Organization: `YourCompany`
     - Country: `SG`
   - **Key algorithm**: RSA 2048 (recommended)
   - **Signing algorithm**: SHA256WITHRSA
4. Click **Create** and note the **ARN**

### Option B: Using AWS CLI

```bash
# Create Private CA
aws acm-pca create-certificate-authority \
  --certificate-authority-configuration '{
    "KeyAlgorithm": "RSA_2048",
    "SigningAlgorithm": "SHA256WITHRSA",
    "Subject": {
      "Country": "SG",
      "Organization": "Demo",
      "CommonName": "demo-services.internal"
    }
  }' \
  --certificate-authority-type "ROOT" \
  --region ap-southeast-1 \
  --profile master-programmatic-admin

# Get the CA ARN from output
# Example: arn:aws:acm-pca:ap-southeast-1:820242905231:certificate-authority/12345678-1234-1234-1234-123456789012
```

### Install CA Certificate

```bash
# Get CSR
aws acm-pca get-certificate-authority-csr \
  --certificate-authority-arn <your-ca-arn> \
  --output text \
  --region ap-southeast-1 \
  --profile master-programmatic-admin > ca.csr

# Issue certificate
aws acm-pca issue-certificate \
  --certificate-authority-arn <your-ca-arn> \
  --csr fileb://ca.csr \
  --signing-algorithm SHA256WITHRSA \
  --template-arn arn:aws:acm-pca:::template/RootCACertificate/V1 \
  --validity Value=10,Type=YEARS \
  --region ap-southeast-1 \
  --profile master-programmatic-admin

# Get the certificate ARN from output, then import it
aws acm-pca get-certificate \
  --certificate-authority-arn <your-ca-arn> \
  --certificate-arn <certificate-arn> \
  --output text \
  --region ap-southeast-1 \
  --profile master-programmatic-admin > ca-cert.pem

# Import CA certificate
aws acm-pca import-certificate-authority-certificate \
  --certificate-authority-arn <your-ca-arn> \
  --certificate fileb://ca-cert.pem \
  --region ap-southeast-1 \
  --profile master-programmatic-admin
```

## ⚙️ Step 2: Configure Terraform

### Update `terraform.tfvars`

```hcl
# Enable Service Connect TLS
enable_service_connect_tls = true

# Set your PCA ARN
aws_pca_authority_arn = "arn:aws:acm-pca:ap-southeast-1:820242905231:certificate-authority/12345678-1234-1234-1234-123456789012"
```

### Or use environment variables

```bash
export TF_VAR_enable_service_connect_tls=true
export TF_VAR_aws_pca_authority_arn="arn:aws:acm-pca:ap-southeast-1:820242905231:certificate-authority/xxxxx"
```

## 🚀 Step 3: Deploy Infrastructure

```bash
# Initialize (first time only)
terraform init

# Plan and review
terraform plan

# Apply
terraform apply -auto-approve
```

## 🔍 What Gets Created

When `enable_service_connect_tls = true`:

### 1. KMS Key
```terraform
resource "aws_kms_key" "service_connect"
```
- Encrypts TLS certificates
- Auto key rotation enabled
- 7-day deletion window

### 2. IAM Role for TLS
```terraform
resource "aws_iam_role" "service_connect_tls"
```
Permissions:
- `acm-pca:GetCertificate`
- `acm-pca:GetCertificateAuthorityCertificate`
- `acm-pca:DescribeCertificateAuthority`
- `kms:Decrypt`
- `kms:GenerateDataKey`

### 3. Service Connect with TLS
```terraform
service_connect_configuration {
  service {
    tls {
      issuer_cert_authority {
        aws_pca_authority_arn = var.aws_pca_authority_arn
      }
      kms_key  = aws_kms_key.service_connect[0].arn
      role_arn = aws_iam_role.service_connect_tls[0].arn
    }
  }
}
```

## 📊 Architecture with TLS

```
┌──────────────────────────────────────────────────────────┐
│                    VPC: 10.0.0.0/16                      │
│                                                           │
│  ┌─────────────────┐           ┌─────────────────┐      │
│  │  Dashboard      │  TLS/HTTPS│  Counting       │      │
│  │  Service        │───────────▶ Service         │      │
│  │                 │           │                 │      │
│  │  Port: 9002     │           │  Port: 9003     │      │
│  └─────────────────┘           └─────────────────┘      │
│         │                              ▲                 │
│         │                              │                 │
│         │      ┌──────────────────────┐│                 │
│         └─────▶│ Service Connect Proxy││                 │
│                │  (Managed by AWS)    ││                 │
│                └──────────────────────┘│                 │
│                        │                │                 │
│                        ▼                │                 │
│                ┌────────────────────────┐                │
│                │  TLS Certificate       │                │
│                │  (from AWS PCA)        │                │
│                └────────────────────────┘                │
└──────────────────────────────────────────────────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │  AWS Private CA       │
            │  (Your Manual Setup)  │
            └───────────────────────┘
```

## ✅ Verification

### 1. Check Service Connect is enabled with TLS

```bash
aws ecs describe-services \
  --cluster demo-cluster \
  --services counting-service \
  --query 'services[0].serviceConnectConfiguration' \
  --profile master-programmatic-admin \
  --region ap-southeast-1
```

Expected output should show `tls` configuration.

### 2. Check CloudWatch Metrics

Service Connect with TLS provides metrics:
- Navigate to **CloudWatch** → **Metrics** → **ECS/ServiceConnect**
- Look for metrics like:
  - `TargetResponseTime`
  - `TargetConnectionErrorCount`
  - `TLSNegotiationErrorCount`

### 3. Test Connectivity

```bash
# Get dashboard task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster demo-cluster \
  --service-name dashboard-service \
  --query 'taskArns[0]' \
  --output text \
  --profile master-programmatic-admin \
  --region ap-southeast-1)

# Test connection (traffic is automatically TLS encrypted)
aws ecs execute-command \
  --cluster demo-cluster \
  --task $TASK_ARN \
  --container dashboard \
  --command "wget -O- http://counting:9003" \
  --interactive \
  --profile master-programmatic-admin \
  --region ap-southeast-1
```

**Note**: Even though you use `http://counting:9003`, Service Connect automatically encrypts the traffic with TLS!

## 💰 Cost Breakdown

| Resource | Monthly Cost (Estimate) |
|----------|-------------------------|
| AWS Private CA | $400/month |
| KMS Key | $1/month |
| Service Connect | Free |
| **Total** | **~$401/month** |

## 🔄 Disable TLS

To disable TLS and save costs:

```bash
# In terraform.tfvars
enable_service_connect_tls = false
# aws_pca_authority_arn = ""  # Comment out

# Apply changes
terraform apply -auto-approve
```

This will:
- ✅ Remove TLS configuration
- ✅ Delete KMS key (after 7 days)
- ✅ Delete IAM role
- ✅ Keep Service Connect running (without TLS)
- ⚠️ **Note**: You must manually delete the AWS PCA to avoid charges!

## 📚 References

- [ECS Service Connect Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-connect.html)
- [AWS Private CA Pricing](https://aws.amazon.com/private-ca/pricing/)
- [Service Connect TLS Configuration](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-connect-tls.html)

## 🎯 Summary

**To enable TLS:**
1. Create AWS Private CA manually (get ARN)
2. Set `enable_service_connect_tls = true`
3. Set `aws_pca_authority_arn = "your-arn"`
4. Run `terraform apply`

**To disable TLS:**
1. Set `enable_service_connect_tls = false`
2. Run `terraform apply`
3. Manually delete AWS PCA to stop charges
