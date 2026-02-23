#!/bin/bash
set -e

echo "🏗️  Building and Pushing Multi-Platform Docker Images to AWS ECR"
echo "=================================================================="
echo ""

# Configuration
COUNTING_DIR="counting"
DASHBOARD_DIR="dashboard"
PLATFORMS="linux/amd64,linux/arm64"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
  echo -e "${RED}❌ Error: Docker buildx is not available!${NC}"
  echo "Please install Docker Desktop or enable buildx."
  exit 1
fi

# Get ECR repository URLs from environment variables (set by Terraform) or from Terraform outputs
if [ -n "$TF_VAR_COUNTING_REPO_URL" ] && [ -n "$TF_VAR_DASHBOARD_REPO_URL" ]; then
  # Called from Terraform with environment variables
  ECR_COUNTING="$TF_VAR_COUNTING_REPO_URL"
  ECR_DASHBOARD="$TF_VAR_DASHBOARD_REPO_URL"
  IMAGE_TAG="${TF_VAR_IMAGE_TAG:-latest}"
  AWS_PROFILE="${TF_VAR_AWS_PROFILE:-}"
else
  # Called manually - get from Terraform outputs
  if ! terraform output -raw counting_service_repository_url 2>&1 | grep -q "public.ecr.aws"; then
    echo -e "${RED}❌ Error: Terraform outputs not found or invalid!${NC}"
    echo ""
    echo "Please run Terraform first to create ECR repositories:"
    echo "  terraform init"
    echo "  terraform apply"
    echo ""
    exit 1
  fi
  
  ECR_COUNTING=$(terraform output -raw counting_service_repository_url 2>/dev/null)
  ECR_DASHBOARD=$(terraform output -raw dashboard_service_repository_url 2>/dev/null)
  IMAGE_TAG=$(terraform output -raw image_tag 2>/dev/null || echo "latest")
  
  # Try to get AWS profile from terraform
  if terraform output aws_profile &> /dev/null; then
    AWS_PROFILE_RAW=$(terraform output -raw aws_profile 2>&1)
    if ! echo "$AWS_PROFILE_RAW" | grep -qE "(Warning:|Error:|╷|╵|│|No value|null)"; then
      AWS_PROFILE=$(echo "$AWS_PROFILE_RAW" | tr -d '\n\r\t' | sed 's/[^a-zA-Z0-9_-]//g')
    fi
  fi
fi

echo -e "${BLUE}📦 Configuration:${NC}"
echo "  ECR Counting:  $ECR_COUNTING:$IMAGE_TAG"
echo "  ECR Dashboard: $ECR_DASHBOARD:$IMAGE_TAG"
echo "  Platforms:     $PLATFORMS"
echo ""

# Setup buildx builder
echo -e "${BLUE}🔧 Setting up Docker buildx...${NC}"
if ! docker buildx ls | grep -q multiplatform; then
  echo "Creating new buildx builder..."
  docker buildx create --name multiplatform --use
  docker buildx inspect --bootstrap
else
  echo "Using existing buildx builder..."
  docker buildx use multiplatform
fi
echo ""

# Login to Public ECR
echo -e "${BLUE}🔐 Logging in to AWS Public ECR...${NC}"
AWS_REGION="us-east-1"

if [ -n "$AWS_PROFILE" ]; then
  echo "Using AWS profile: $AWS_PROFILE"
  aws ecr-public get-login-password --region $AWS_REGION --profile "$AWS_PROFILE" | \
    docker login --username AWS --password-stdin public.ecr.aws
else
  echo "Using default AWS credentials"
  aws ecr-public get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin public.ecr.aws
fi

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to login to ECR${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Successfully logged in to ECR${NC}"
echo ""

# Check if Dockerfiles exist
if [ ! -f "$COUNTING_DIR/Dockerfile" ]; then
  echo -e "${RED}❌ Error: Dockerfile not found in '$COUNTING_DIR'!${NC}"
  exit 1
fi

if [ ! -f "$DASHBOARD_DIR/Dockerfile" ]; then
  echo -e "${RED}❌ Error: Dockerfile not found in '$DASHBOARD_DIR'!${NC}"
  exit 1
fi

# Build and push counting service with multi-platform support
echo -e "${BLUE}🏗️  Building and pushing counting service (multi-platform)...${NC}"
echo "   Directory: $COUNTING_DIR"
echo "   Image: $ECR_COUNTING:$IMAGE_TAG"
echo "   Platforms: $PLATFORMS"
echo ""

docker buildx build \
  --platform $PLATFORMS \
  -t $ECR_COUNTING:$IMAGE_TAG \
  -f $COUNTING_DIR/Dockerfile \
  --push \
  $COUNTING_DIR

echo ""
echo -e "${GREEN}✅ Counting service built and pushed to ECR!${NC}"
echo ""

# Build and push dashboard service with multi-platform support
echo -e "${BLUE}🏗️  Building and pushing dashboard service (multi-platform)...${NC}"
echo "   Directory: $DASHBOARD_DIR"
echo "   Image: $ECR_DASHBOARD:$IMAGE_TAG"
echo "   Platforms: $PLATFORMS"
echo ""

docker buildx build \
  --platform $PLATFORMS \
  -t $ECR_DASHBOARD:$IMAGE_TAG \
  -f $DASHBOARD_DIR/Dockerfile \
  --push \
  $DASHBOARD_DIR

echo ""
echo -e "${GREEN}✅ Dashboard service built and pushed to ECR!${NC}"
echo ""

echo "🎉 All multi-platform images built and pushed to AWS ECR!"
echo ""
echo "📋 Summary:"
echo "  ✓ Counting:  $ECR_COUNTING:$IMAGE_TAG"
echo "  ✓ Dashboard: $ECR_DASHBOARD:$IMAGE_TAG"
echo ""
echo "📊 Platforms available:"
echo "   ✓ linux/amd64 (Intel/AMD Linux, ECS x86_64)"
echo "   ✓ linux/arm64 (Mac M1/M2, ECS ARM64)"
echo ""
echo "🔍 Verify multi-platform images:"
echo "  docker buildx imagetools inspect $ECR_COUNTING:$IMAGE_TAG"
echo "  docker buildx imagetools inspect $ECR_DASHBOARD:$IMAGE_TAG"
echo ""
echo "🚀 Deploy to ECS:"
echo "  terraform apply"
echo ""
echo -e "${YELLOW}💡 Note: Multi-platform builds${NC}"
echo "  Images are built for both amd64 and arm64 architectures."
echo "  ECS will automatically pull the correct platform based on your task definition."
