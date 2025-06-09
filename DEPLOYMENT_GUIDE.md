# 1stDibs Extractor - Deployment Guide 🚀

## Quick Start

### Option 1: Local Deployment (No Registry Required)

This is the easiest way to get started - no Docker registry needed!

```bash
# 1. Prepare your URLs
python deployment/prepare_chunks.py urls.txt 5000

# 2. Deploy locally
./deployment/deploy_local.sh

# 3. Follow the prompts to deploy containers
```

### Option 2: Production Deployment with Registry

```bash
# 1. Prepare chunks
python deployment/prepare_chunks.py urls.txt 5000

# 2. Build base image
docker build -t 1stdibs-extractor:latest -f docker/Dockerfile .

# 3. Build all chunk images
./deployment/build_images.sh

# 4. Push to your registry
./deployment/push_images_fixed.sh docker.io/yourusername
# or
./deployment/push_images_fixed.sh 123456789.dkr.ecr.us-west-2.amazonaws.com
# or
./deployment/push_images_fixed.sh gcr.io/your-project-id
```

## Registry Configuration

### Docker Hub
```bash
# Login
docker login

# Push
./deployment/push_images_fixed.sh docker.io/yourusername
```

### AWS ECR
```bash
# Login
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.us-west-2.amazonaws.com

# Push
./deployment/push_images_fixed.sh 123456789.dkr.ecr.us-west-2.amazonaws.com
```

### Google Container Registry
```bash
# Login
gcloud auth configure-docker

# Push
./deployment/push_images_fixed.sh gcr.io/your-project-id
```

### Azure Container Registry
```bash
# Login
az acr login --name myregistry

# Push
./deployment/push_images_fixed.sh myregistry.azurecr.io
```

### Local Registry
```bash
# Start local registry
docker run -d -p 5000:5000 --name registry registry:2

# Push
./deployment/push_images_fixed.sh localhost:5000
```

## Deployment Options

### 1. Docker Compose (Recommended for <20 containers)

Update the registry in docker-compose.yml if using a registry:
```yaml
services:
  extractor-phoenix:
    image: $REGISTRY/1stdibs-extractor:phoenix  # Update this
    # or for local:
    image: 1stdibs-extractor:latest
```

Deploy:
```bash
docker-compose -f deployment/docker-compose.yml up -d
```

### 2. Kubernetes

Update image references in k8s files:
```yaml
spec:
  containers:
  - name: extractor
    image: $REGISTRY/1stdibs-extractor:phoenix  # Update this
```

Deploy:
```bash
kubectl apply -f deployment/k8s/
```

### 3. Docker Swarm

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c deployment/docker-compose.yml 1stdibs
```

## Monitoring

### View Container Status
```bash
# All containers
docker ps --filter "name=1stdibs-"

# Specific container logs
docker logs -f 1stdibs-phoenix
```

### Check Progress
```bash
# Summary for one container
cat data/phoenix/container_phoenix_summary.json

# Count total extracted
find data/*/extracted -name "*.json" | wc -l

# View errors
grep ERROR data/*/logs/extraction.log
```

### Real-time Monitoring
```bash
# Watch progress
watch -n 5 'find data/*/extracted -name "*.json" | wc -l'

# Monitor specific container
watch -n 10 'cat data/phoenix/container_phoenix_summary.json | jq .'
```

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs 1stdibs-phoenix

# Common issues:
# - Missing URL chunk file
# - Insufficient disk space
# - Port conflicts
```

### Slow Processing
```bash
# Increase workers
docker run -d \
  -e MAX_WORKERS=8 \
  -e DELAY_MIN=0.2 \
  ...
```

### Registry Push Fails
```bash
# Check login
docker login $REGISTRY

# Check image exists
docker images | grep 1stdibs-extractor

# Try manual push
docker push $REGISTRY/1stdibs-extractor:phoenix
```

## Scaling

### Local Scaling
- Run multiple instances of deploy_local.sh
- Each deployment creates unique containers

### Cloud Scaling
- **AWS**: Use ECS with auto-scaling groups
- **GCP**: Use Cloud Run with concurrency settings
- **Azure**: Use Container Instances

### Performance Tuning
```bash
# Environment variables for performance
-e MAX_WORKERS=8        # More parallel threads
-e DELAY_MIN=0.2       # Reduce delay
-e TIMEOUT=60          # Increase timeout for slow connections
```

## Data Management

### Backup Extracted Data
```bash
# Local backup
tar -czf backup-$(date +%Y%m%d).tar.gz data/

# S3 backup
aws s3 sync data/ s3://my-bucket/1stdibs-data/

# GCS backup
gsutil -m rsync -r data/ gs://my-bucket/1stdibs-data/
```

### Clean Up
```bash
# Stop all containers
docker stop $(docker ps -q --filter "name=1stdibs-")

# Remove containers
docker rm $(docker ps -aq --filter "name=1stdibs-")

# Clean images (keep base)
docker rmi $(docker images -q "1stdibs-extractor" | grep -v latest)
```

## Quick Reference

```bash
# Test setup
./verify_deployment.sh

# Local deployment (easiest)
./deployment/deploy_local.sh

# Full deployment with registry
./deployment/push_images_fixed.sh <registry>

# Monitor progress
watch -n 5 'docker ps --filter "name=1stdibs-" --format "table {{.Names}}\t{{.Status}}"'
```