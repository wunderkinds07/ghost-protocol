#!/bin/bash
# Quick AWS deployment script for 1stDibs Extractor

echo "🚀 AWS Quick Deployment for 1stDibs Extractor"
echo "============================================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first:"
    echo "   brew install awscli"
    echo "   aws configure"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker Desktop."
    exit 1
fi

# Get AWS account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ AWS CLI not configured. Run: aws configure"
    exit 1
fi

REGION=${AWS_DEFAULT_REGION:-us-east-1}
echo "✅ AWS Account: $ACCOUNT_ID"
echo "✅ Region: $REGION"
echo ""

# Step 1: Create ECR repository
echo "📦 Step 1: Creating ECR repository..."
aws ecr create-repository \
    --repository-name 1stdibs-extractor \
    --region $REGION 2>/dev/null || echo "   Repository already exists"

ECR_URI=$(aws ecr describe-repositories \
    --repository-names 1stdibs-extractor \
    --region $REGION \
    --query 'repositories[0].repositoryUri' \
    --output text)

echo "✅ ECR Repository: $ECR_URI"
echo ""

# Step 2: Build and push Docker image
echo "🐳 Step 2: Building and pushing Docker image..."
echo "   Logging into ECR..."
aws ecr get-login-password --region $REGION | \
    docker login --username AWS --password-stdin ${ECR_URI%/*}

echo "   Building image..."
docker build -t 1stdibs-extractor:latest -f docker/Dockerfile .

echo "   Tagging image..."
docker tag 1stdibs-extractor:latest $ECR_URI:latest

echo "   Pushing to ECR..."
docker push $ECR_URI:latest
echo "✅ Image pushed successfully"
echo ""

# Step 3: Create S3 bucket
echo "🪣 Step 3: Creating S3 bucket..."
BUCKET_NAME="1stdibs-extractor-${ACCOUNT_ID}-${REGION}"
aws s3 mb s3://$BUCKET_NAME --region $REGION 2>/dev/null || echo "   Bucket already exists"
echo "✅ S3 Bucket: $BUCKET_NAME"
echo ""

# Step 4: Create IAM role
echo "🔐 Step 4: Setting up IAM roles..."

# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create task role
aws iam create-role \
    --role-name 1stDibsECSTaskRole \
    --assume-role-policy-document file://trust-policy.json \
    2>/dev/null || echo "   Role already exists"

# Attach policies
aws iam attach-role-policy \
    --role-name 1stDibsECSTaskRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
    2>/dev/null || true

# Create S3 policy
cat > s3-policy.json << EOF
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
        "arn:aws:s3:::${BUCKET_NAME}/*",
        "arn:aws:s3:::${BUCKET_NAME}"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name 1stDibsECSTaskRole \
    --policy-name S3Access \
    --policy-document file://s3-policy.json \
    2>/dev/null || true

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/1stDibsECSTaskRole"
echo "✅ IAM Role: $ROLE_ARN"
echo ""

# Step 5: Create ECS cluster
echo "🌊 Step 5: Creating ECS cluster..."
aws ecs create-cluster \
    --cluster-name 1stdibs-extraction \
    --region $REGION \
    --capacity-providers FARGATE FARGATE_SPOT \
    2>/dev/null || echo "   Cluster already exists"
echo "✅ ECS Cluster: 1stdibs-extraction"
echo ""

# Step 6: Create CloudWatch log group
echo "📊 Step 6: Setting up CloudWatch logs..."
aws logs create-log-group \
    --log-group-name /ecs/1stdibs-extractor \
    --region $REGION \
    2>/dev/null || echo "   Log group already exists"
echo "✅ Log Group: /ecs/1stdibs-extractor"
echo ""

# Step 7: Get networking info
echo "🌐 Step 7: Getting VPC information..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --region $REGION \
    --query "Vpcs[0].VpcId" \
    --output text)

SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region $REGION \
    --query "Subnets[*].SubnetId" \
    --output text | tr '\t' ',')

# Create security group
SG_ID=$(aws ec2 create-security-group \
    --group-name 1stdibs-extractor-sg \
    --description "Security group for 1stDibs extractor" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'GroupId' \
    --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=1stdibs-extractor-sg" \
        --region $REGION \
        --query 'SecurityGroups[0].GroupId' \
        --output text)

echo "✅ VPC: $VPC_ID"
echo "✅ Security Group: $SG_ID"
echo ""

# Step 8: Create task definition
echo "📝 Step 8: Creating task definition..."

cat > task-definition.json << EOF
{
  "family": "1stdibs-extractor",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "${ROLE_ARN}",
  "taskRoleArn": "${ROLE_ARN}",
  "containerDefinitions": [
    {
      "name": "extractor",
      "image": "${ECR_URI}:latest",
      "essential": true,
      "environment": [
        {"name": "CONTAINER_ID", "value": "aws-container"},
        {"name": "CHUNK_NAME", "value": "phoenix"},
        {"name": "URL_CHUNK_START", "value": "0"},
        {"name": "URL_CHUNK_SIZE", "value": "5000"},
        {"name": "NTFY_TOPIC", "value": "callofdutyblackopsghostprotocolbravo64"},
        {"name": "S3_BUCKET", "value": "${BUCKET_NAME}"},
        {"name": "AWS_DEFAULT_REGION", "value": "${REGION}"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/1stdibs-extractor",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --region $REGION > /dev/null

echo "✅ Task definition registered"
echo ""

# Step 9: Create deployment script
echo "🚀 Step 9: Creating deployment script..."

cat > deploy-tasks.sh << EOF
#!/bin/bash
# Deploy multiple containers to AWS ECS

CLUSTER="1stdibs-extraction"
TASK_DEF="1stdibs-extractor"
SUBNETS="${SUBNET_IDS}"
SECURITY_GROUP="${SG_ID}"
REGION="${REGION}"

# Container names
CONTAINERS=("phoenix" "gallardo" "nebula" "dragon" "tiger" "eagle" "falcon" "cobra")

echo "🚀 Deploying containers to AWS ECS"
echo "================================="
echo ""

# Deploy each container
for i in "\${!CONTAINERS[@]}"; do
    CONTAINER_NAME="\${CONTAINERS[\$i]}"
    START_INDEX=\$((i * 5000))
    
    echo "📦 Deploying \$CONTAINER_NAME (URLs \$START_INDEX-\$((START_INDEX + 4999)))"
    
    TASK_ARN=\$(aws ecs run-task \\
        --cluster \$CLUSTER \\
        --task-definition \$TASK_DEF \\
        --launch-type FARGATE \\
        --network-configuration "awsvpcConfiguration={subnets=[\$SUBNETS],securityGroups=[\$SECURITY_GROUP],assignPublicIp=ENABLED}" \\
        --region \$REGION \\
        --overrides "{
            \\"containerOverrides\\": [{
                \\"name\\": \\"extractor\\",
                \\"environment\\": [
                    {\\"name\\": \\"CONTAINER_ID\\", \\"value\\": \\"\$CONTAINER_NAME\\"},
                    {\\"name\\": \\"CHUNK_NAME\\", \\"value\\": \\"\$CONTAINER_NAME\\"},
                    {\\"name\\": \\"URL_CHUNK_START\\", \\"value\\": \\"\$START_INDEX\\"}
                ]
            }]
        }" \\
        --query 'tasks[0].taskArn' \\
        --output text)
    
    if [ ! -z "\$TASK_ARN" ]; then
        echo "✅ Deployed \$CONTAINER_NAME"
        echo "   Task: \$TASK_ARN"
    else
        echo "❌ Failed to deploy \$CONTAINER_NAME"
    fi
    
    echo ""
    sleep 2
done

echo "📊 View running tasks:"
echo "   aws ecs list-tasks --cluster \$CLUSTER --region \$REGION"
echo ""
echo "📋 View logs:"
echo "   aws logs tail /ecs/1stdibs-extractor --follow --region \$REGION"
echo ""
echo "📢 Monitor notifications:"
echo "   https://ntfy.sh/callofdutyblackopsghostprotocolbravo64"
EOF

chmod +x deploy-tasks.sh

# Clean up temp files
rm -f trust-policy.json s3-policy.json task-definition.json

# Final summary
echo "✅ AWS Deployment Setup Complete!"
echo "================================="
echo ""
echo "📋 Resources Created:"
echo "   - ECR Repository: $ECR_URI"
echo "   - S3 Bucket: $BUCKET_NAME"
echo "   - ECS Cluster: 1stdibs-extraction"
echo "   - IAM Role: 1stDibsECSTaskRole"
echo "   - Security Group: $SG_ID"
echo ""
echo "🚀 To deploy containers:"
echo "   ./deploy-tasks.sh"
echo ""
echo "📊 To monitor:"
echo "   - CloudWatch Logs: aws logs tail /ecs/1stdibs-extractor --follow"
echo "   - Notifications: https://ntfy.sh/callofdutyblackopsghostprotocolbravo64"
echo "   - ECS Console: https://console.aws.amazon.com/ecs/home?region=$REGION#/clusters/1stdibs-extraction"
echo ""
echo "💰 Estimated cost:"
echo "   - Fargate: ~\$0.05/hour per container"
echo "   - S3: ~\$0.023/GB/month"
echo "   - Total for 20 containers (2 hours): ~\$2.00"
echo ""
echo "🛑 To stop all tasks:"
echo "   aws ecs list-tasks --cluster 1stdibs-extraction | jq -r '.taskArns[]' | xargs -I {} aws ecs stop-task --cluster 1stdibs-extraction --task {}"