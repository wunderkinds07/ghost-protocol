# AWS Deployment Guide for 1stDibs Extractor 🚀

## Overview
This guide will help you deploy the 1stDibs extraction pipeline to AWS using ECS (Elastic Container Service) with Fargate for serverless container management.

## Prerequisites

1. **AWS Account** - You already have this ✓
2. **AWS CLI** - Install if not already:
   ```bash
   brew install awscli
   aws configure
   ```
3. **Docker** - For building images locally

## Step-by-Step Deployment

### Step 1: Create ECR Repository

First, let's create a repository to store your Docker images:

```bash
# Create ECR repository
aws ecr create-repository \
    --repository-name 1stdibs-extractor \
    --region us-east-1

# Get the repository URI (save this!)
aws ecr describe-repositories \
    --repository-names 1stdibs-extractor \
    --region us-east-1 \
    --query 'repositories[0].repositoryUri' \
    --output text
```

### Step 2: Build and Push Docker Image

```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    $(aws ecr describe-repositories --repository-names 1stdibs-extractor --query 'repositories[0].repositoryUri' --output text | cut -d'/' -f1)

# Build the Docker image
docker build -t 1stdibs-extractor:latest -f docker/Dockerfile .

# Tag for ECR (replace with your repository URI)
ECR_URI=$(aws ecr describe-repositories --repository-names 1stdibs-extractor --query 'repositories[0].repositoryUri' --output text)
docker tag 1stdibs-extractor:latest $ECR_URI:latest

# Push to ECR
docker push $ECR_URI:latest
```

### Step 3: Create S3 Bucket for Data Storage

```bash
# Create S3 bucket for extracted data
BUCKET_NAME="1stdibs-extracted-data-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1

echo "Your S3 bucket: $BUCKET_NAME"
```

### Step 4: Create IAM Role for ECS Tasks

Create a file called `ecs-task-role-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR_BUCKET_NAME/*",
        "arn:aws:s3:::YOUR_BUCKET_NAME"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

Create the role:

```bash
# Create task execution role
aws iam create-role \
    --role-name ecsTaskExecutionRole1stDibs \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "ecs-tasks.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

# Attach policies
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole1stDibs \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Create and attach custom policy for S3
aws iam put-role-policy \
    --role-name ecsTaskExecutionRole1stDibs \
    --policy-name S3Access \
    --policy-document file://ecs-task-role-policy.json
```

### Step 5: Create ECS Cluster

```bash
# Create ECS cluster
aws ecs create-cluster \
    --cluster-name 1stdibs-extraction-cluster \
    --region us-east-1
```

### Step 6: Create Task Definition

Create `task-definition.json`:

```json
{
  "family": "1stdibs-extractor",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskExecutionRole1stDibs",
  "taskRoleArn": "arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskExecutionRole1stDibs",
  "containerDefinitions": [
    {
      "name": "extractor",
      "image": "YOUR_ECR_URI:latest",
      "essential": true,
      "environment": [
        {"name": "CONTAINER_ID", "value": "phoenix"},
        {"name": "CHUNK_NAME", "value": "phoenix"},
        {"name": "URL_CHUNK_START", "value": "0"},
        {"name": "URL_CHUNK_SIZE", "value": "5000"},
        {"name": "NTFY_TOPIC", "value": "callofdutyblackopsghostprotocolbravo64"},
        {"name": "S3_BUCKET", "value": "YOUR_BUCKET_NAME"},
        {"name": "AWS_DEFAULT_REGION", "value": "us-east-1"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/1stdibs-extractor",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

Register the task definition:

```bash
# Create log group
aws logs create-log-group --log-group-name /ecs/1stdibs-extractor --region us-east-1

# Register task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

### Step 7: Create VPC and Security Group (if needed)

```bash
# Get default VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)

# Get subnets
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)

# Create security group
SECURITY_GROUP=$(aws ec2 create-security-group \
    --group-name 1stdibs-extractor-sg \
    --description "Security group for 1stDibs extractor" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)

# Allow outbound traffic
aws ec2 authorize-security-group-egress \
    --group-id $SECURITY_GROUP \
    --protocol all \
    --cidr 0.0.0.0/0
```

### Step 8: Deploy Tasks

Create a deployment script `deploy-to-aws.sh`:

```bash
#!/bin/bash

# Configuration
CLUSTER="1stdibs-extraction-cluster"
TASK_DEFINITION="1stdibs-extractor"
SUBNETS="subnet-xxx,subnet-yyy"  # Replace with your subnets
SECURITY_GROUP="sg-xxx"  # Replace with your security group

# Chunk names
CHUNKS=("phoenix" "gallardo" "nebula" "dragon" "tiger" "eagle" "falcon" "cobra")

# Deploy each chunk as a separate task
for i in "${!CHUNKS[@]}"; do
    CHUNK_NAME="${CHUNKS[$i]}"
    START_INDEX=$((i * 5000))
    
    echo "Deploying $CHUNK_NAME (URLs $START_INDEX-$((START_INDEX + 4999)))"
    
    aws ecs run-task \
        --cluster $CLUSTER \
        --task-definition $TASK_DEFINITION \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
        --overrides "{
            \"containerOverrides\": [{
                \"name\": \"extractor\",
                \"environment\": [
                    {\"name\": \"CONTAINER_ID\", \"value\": \"$CHUNK_NAME\"},
                    {\"name\": \"CHUNK_NAME\", \"value\": \"$CHUNK_NAME\"},
                    {\"name\": \"URL_CHUNK_START\", \"value\": \"$START_INDEX\"}
                ]
            }]
        }"
    
    echo "✅ Deployed $CHUNK_NAME"
    sleep 5  # Avoid rate limiting
done
```

### Step 9: Monitor Deployment

```bash
# View running tasks
aws ecs list-tasks --cluster 1stdibs-extraction-cluster

# View task details
aws ecs describe-tasks \
    --cluster 1stdibs-extraction-cluster \
    --tasks $(aws ecs list-tasks --cluster 1stdibs-extraction-cluster --query 'taskArns[0]' --output text)

# View logs
aws logs tail /ecs/1stdibs-extractor --follow

# Monitor notifications
echo "📢 Monitor progress at: https://ntfy.sh/callofdutyblackopsghostprotocolbravo64"
```

## Cost Optimization

### Fargate Pricing (us-east-1)
- vCPU: $0.04048 per vCPU per hour
- Memory: $0.004445 per GB per hour

For our configuration (1 vCPU, 2GB RAM):
- Hourly cost: ~$0.05 per container
- If processing takes 2 hours: ~$0.10 per container
- 20 containers = ~$2.00 total

### Cost-Saving Tips

1. **Use Spot Fargate** (70% savings):
```bash
# Add to run-task command:
--capacity-provider-strategy capacityProvider=FARGATE_SPOT,weight=1
```

2. **Process in batches**:
- Deploy 5-10 containers at a time
- Monitor completion
- Deploy next batch

3. **Use smaller instances for testing**:
```json
"cpu": "512",
"memory": "1024"
```

## Quick Deployment Script

I'll create a complete deployment script for you:

```bash
#!/bin/bash
# save as: aws-quick-deploy.sh

echo "🚀 AWS Deployment for 1stDibs Extractor"
echo "======================================"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📍 AWS Account: $ACCOUNT_ID"

# Create ECR repository
echo "📦 Creating ECR repository..."
aws ecr create-repository --repository-name 1stdibs-extractor --region us-east-1 2>/dev/null || true
ECR_URI=$(aws ecr describe-repositories --repository-names 1stdibs-extractor --query 'repositories[0].repositoryUri' --output text)
echo "✅ ECR URI: $ECR_URI"

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_URI%/*}

# Build and push image
echo "🐳 Building Docker image..."
docker build -t 1stdibs-extractor:latest -f docker/Dockerfile .
docker tag 1stdibs-extractor:latest $ECR_URI:latest
docker push $ECR_URI:latest
echo "✅ Image pushed to ECR"

# Create S3 bucket
BUCKET_NAME="1stdibs-data-$ACCOUNT_ID"
echo "🪣 Creating S3 bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region us-east-1 2>/dev/null || true

# Create ECS cluster
echo "🌊 Creating ECS cluster..."
aws ecs create-cluster --cluster-name 1stdibs-extraction --region us-east-1 2>/dev/null || true

echo ""
echo "✅ AWS infrastructure ready!"
echo ""
echo "📋 Next steps:"
echo "1. Update task-definition.json with:"
echo "   - ECR URI: $ECR_URI"
echo "   - Account ID: $ACCOUNT_ID"
echo "   - S3 Bucket: $BUCKET_NAME"
echo ""
echo "2. Register task definition:"
echo "   aws ecs register-task-definition --cli-input-json file://task-definition.json"
echo ""
echo "3. Run tasks:"
echo "   ./deploy-to-aws.sh"
echo ""
echo "📢 Monitor at: https://ntfy.sh/callofdutyblackopsghostprotocolbravo64"
```

## Monitoring & Management

### CloudWatch Dashboard
```bash
# Create dashboard for monitoring
aws cloudwatch put-dashboard \
    --dashboard-name 1stDibs-Extraction \
    --dashboard-body file://cloudwatch-dashboard.json
```

### Stop All Tasks
```bash
# Stop all running tasks
for task in $(aws ecs list-tasks --cluster 1stdibs-extraction-cluster --query 'taskArns[]' --output text); do
    aws ecs stop-task --cluster 1stdibs-extraction-cluster --task $task
done
```

### Download Results from S3
```bash
# Sync all extracted data
aws s3 sync s3://$BUCKET_NAME/extracted/ ./aws-results/
```

## Troubleshooting

1. **Task fails immediately**
   - Check CloudWatch logs
   - Verify IAM permissions
   - Check security group allows outbound traffic

2. **Can't push to ECR**
   - Re-run ECR login command
   - Check IAM permissions for ECR

3. **Out of memory errors**
   - Increase task memory to 4096
   - Reduce MAX_WORKERS environment variable

## Total Deployment Time: ~30 minutes

Ready to deploy! Any questions about specific steps?