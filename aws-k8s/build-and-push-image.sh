#!/bin/bash
# Build and push Ghost Protocol Docker image to ECR

set -e

REGION=${1:-us-east-1}
IMAGE_TAG=${2:-latest}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Building and pushing Ghost Protocol image to $REGION ===${NC}"

# Get ECR repository URI
ECR_URI=$(aws ecr describe-repositories --repository-names ghost-protocol --region $REGION --query 'repositories[0].repositoryUri' --output text)
FULL_IMAGE_URI="$ECR_URI:$IMAGE_TAG"

echo "Image will be pushed to: $FULL_IMAGE_URI"

# Login to ECR
echo -e "${YELLOW}Logging into ECR...${NC}"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Build image
echo -e "${YELLOW}Building Docker image...${NC}"
cd ..  # Go back to project root
docker build -f k8s/Dockerfile-k8s -t ghost-protocol:$IMAGE_TAG .
docker tag ghost-protocol:$IMAGE_TAG $FULL_IMAGE_URI

# Push image
echo -e "${YELLOW}Pushing image to ECR...${NC}"
docker push $FULL_IMAGE_URI

echo -e "${GREEN}✓ Image pushed successfully${NC}"
echo "Image URI: $FULL_IMAGE_URI"

# Update image reference file
echo "$FULL_IMAGE_URI" > image-uri-$REGION.txt

echo -e "${GREEN}=== Image build and push complete ===${NC}"
echo "Image URI saved to: image-uri-$REGION.txt"