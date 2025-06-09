# Better Alternatives to Lightsail Container Service

## Option 1: Lightsail Instance + Docker (Recommended)
**Cost**: $20-40/month
```bash
# Create Lightsail instance (not container service)
aws lightsail create-instances \
  --instance-names "1stdibs-processor" \
  --availability-zone us-east-1a \
  --blueprint-id ubuntu_20_04 \
  --bundle-id medium_2_0  # 2 vCPU, 4 GB RAM

# SSH in and run Docker containers
ssh ubuntu@instance-ip
docker run -d --name extractor-1 ...
```

**Pros**:
- Full control over containers
- Can run 10-20 containers on single instance
- Use local storage
- Much cheaper

## Option 2: AWS Batch
**Cost**: Pay only for processing time
```bash
# Submit batch jobs that run containers
aws batch submit-job \
  --job-name "1stdibs-extraction" \
  --job-queue "my-queue" \
  --job-definition "extractor-job"
```

**Pros**:
- Automatic scaling
- Pay per second
- Handles failures/retries
- Perfect for batch processing

## Option 3: ECS Fargate with ECS CLI
**Cost**: ~$0.04/hour per container
```bash
# Deploy task definition
ecs-cli compose up \
  --cluster my-cluster \
  --launch-type FARGATE
```

**Pros**:
- No servers to manage
- Scale to 200+ tasks easily
- Pay only while running

## Option 4: Lambda Container Support
**Cost**: $0.0000166667 per GB-second
```python
# Package as Lambda container
# Process URLs in 15-minute chunks
def handler(event, context):
    process_url_batch(event['urls'])
```

**Pros**:
- Extremely cost-effective
- Automatic scaling
- No infrastructure

## CloudShell Usage

AWS CloudShell can help with:
1. **Building and pushing images**:
```bash
# In CloudShell
docker build -t my-extractor .
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URI
docker push $ECR_URI/my-extractor
```

2. **Managing deployments**:
```bash
# Deploy to ECS/Batch/Lambda
aws ecs run-task --cluster my-cluster --task-definition extractor
```

3. **Monitoring progress**:
```bash
# Check logs
aws logs tail /ecs/extractor --follow
```

## Recommended Architecture

```
CloudShell (Management)
    ↓
ECR (Container Registry)
    ↓
ECS Fargate / EC2 (Execution)
    ↓
S3 (Storage)
```

This gives you:
- Scalability (200+ containers)
- Cost efficiency (pay per use)
- No server management
- Easy monitoring

## Quick Decision Matrix

| Need | Best Option |
|------|------------|
| Cheapest | Single EC2/Lightsail Instance |
| Easiest | ECS Fargate |
| Most Scalable | AWS Batch |
| Fastest Setup | Lightsail Instance |
| Best for 1M URLs | AWS Batch or ECS |