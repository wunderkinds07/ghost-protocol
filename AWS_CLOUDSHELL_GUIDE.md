# AWS CloudShell Deployment Guide

## 🌐 Deploy Ghost Protocol Using AWS CloudShell (100% Browser-Based!)

AWS CloudShell is a browser-based shell environment with AWS CLI pre-configured. Perfect for deployment without installing anything locally!

## What is AWS CloudShell?

- **Browser-based terminal** - No local software needed
- **AWS CLI pre-installed** - Already authenticated with your account
- **Pre-configured environment** - Docker, git, and common tools included
- **Persistent storage** - Your files persist between sessions
- **Free to use** - No additional charges for CloudShell itself

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Web browser** - That's it!

## Step-by-Step Deployment

### Phase 1: Launch CloudShell (1 minute)

1. **Login to AWS Console**: [console.aws.amazon.com](https://console.aws.amazon.com)
2. **Launch CloudShell**: 
   - Look for the CloudShell icon (terminal icon) in the top toolbar
   - OR go to Services → CloudShell
   - OR click the `>_` icon in the AWS Console header
3. **Wait for environment** to initialize (30-60 seconds)

You'll see a terminal like this:
```
[cloudshell-user@ip-10-0-123-456 ~]$ 
```

### Phase 2: Setup Ghost Protocol (5 minutes)

#### Download and Setup
```bash
# 1. Create project directory
mkdir ghost-protocol && cd ghost-protocol

# 2. Download the CloudShell setup script
curl -o setup-cloudshell.sh https://raw.githubusercontent.com/your-repo/ghost-protocol/main/aws-cloudshell/setup-cloudshell.sh

# 3. Make it executable and run
chmod +x setup-cloudshell.sh
./setup-cloudshell.sh
```

Or manually create the setup:

```bash
# Install eksctl (CloudShell doesn't have it by default)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
aws --version
docker --version
kubectl version --client
eksctl version
helm version

echo "✅ CloudShell environment ready!"
```

### Phase 3: Prepare Your Data (5 minutes)

#### Upload Your URLs File
```bash
# Option 1: Upload via CloudShell file upload feature
# Click Actions → Upload file in CloudShell interface
# Upload your URLs file

# Option 2: Create sample URLs for testing
cat > sample-urls.txt << 'EOF'
https://www.1stdibs.com/furniture/seating/benches/mid-century-modern-wooden-bench-unknown-danish-cabinetmaker-1960s/id-f_31310552/
https://www.1stdibs.com/furniture/seating/chairs/mid-century-modern-stacking-chairs-verner-panton-herman-miller-1960s/id-f_1234567/
https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-modern-dining-table-carlo-scarpa-1970s/id-f_2345678/
https://www.1stdibs.com/furniture/storage-case-pieces/cabinets/danish-modern-teak-cabinet-arne-vodder-1960s/id-f_3456789/
https://www.1stdibs.com/furniture/lighting/floor-lamps/italian-arc-floor-lamp-achille-castiglioni-flos-1962/id-f_4567890/
EOF

# Create URL chunks
python3 -c "
import os
urls_file = 'sample-urls.txt'  # Replace with your file
chunk_size = 5000
output_dir = 'chunks'

os.makedirs(output_dir, exist_ok=True)

with open(urls_file, 'r') as f:
    urls = [line.strip() for line in f if line.strip()]

total_urls = len(urls)
num_chunks = (total_urls + chunk_size - 1) // chunk_size

print(f'Total URLs: {total_urls}')
print(f'Creating {num_chunks} chunks of up to {chunk_size} URLs each')

for i in range(num_chunks):
    start_idx = i * chunk_size
    end_idx = min((i + 1) * chunk_size, total_urls)
    chunk_urls = urls[start_idx:end_idx]
    
    chunk_filename = f'urls_chunk_{i+1:04d}.txt'
    chunk_path = os.path.join(output_dir, chunk_filename)
    
    with open(chunk_path, 'w') as f:
        for url in chunk_urls:
            f.write(url + '\n')
    
    print(f'Created {chunk_filename}: {len(chunk_urls)} URLs')
"

ls chunks/
```

### Phase 4: Deploy to AWS (20 minutes)

#### Single Region Deployment
```bash
# Set your preferred region
export AWS_REGION=$(aws configure get region || echo "us-east-1")
export CLUSTER_NAME="ghost-protocol"

echo "Deploying to region: $AWS_REGION"

# 1. Create EKS cluster (takes 15-20 minutes)
echo "🚀 Creating EKS cluster (this takes 15-20 minutes)..."
eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $AWS_REGION \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 1 \
    --nodes-max 5 \
    --with-oidc \
    --managed

echo "✅ EKS cluster created!"

# 2. Create ECR repository
echo "📦 Creating ECR repository..."
aws ecr create-repository --repository-name ghost-protocol --region $AWS_REGION || echo "Repository already exists"

# Get ECR URI
export ECR_URI=$(aws ecr describe-repositories --repository-names ghost-protocol --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text)
echo "ECR URI: $ECR_URI"
```

#### Build and Push Docker Image
```bash
# 3. Create Dockerfile in CloudShell
cat > Dockerfile << 'EOF'
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y wget curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python packages
RUN pip install requests beautifulsoup4 lxml tqdm pandas numpy

# Create demo entrypoint
RUN cat > entrypoint.py << 'PYEOF'
#!/usr/bin/env python3
import os
import sys
import json
import time
from pathlib import Path

print("🚀 Ghost Protocol CloudShell Demo")
print(f"Container ID: {os.environ.get('CONTAINER_ID', 'cloudshell')}")

urls_file = os.environ.get('URLS_FILE', '/app/data/urls_chunk.txt')
output_dir = Path('/app/data/output')
output_dir.mkdir(parents=True, exist_ok=True)

if os.path.exists(urls_file):
    with open(urls_file, 'r') as f:
        urls = [line.strip() for line in f if line.strip()]
    
    print(f"📁 Processing {len(urls)} URLs")
    
    for i, url in enumerate(urls, 1):
        print(f"🔄 Processing {i}/{len(urls)}: {url}")
        
        # Demo extraction
        result = {
            "url": url,
            "processed_at": time.time(),
            "status": "demo_success",
            "demo_data": {
                "title": f"Demo Product {i}",
                "description": "CloudShell demo extraction"
            }
        }
        
        # Save result
        output_file = output_dir / f"result_{i:04d}.json"
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2)
        
        print(f"✅ Saved: {output_file}")
        time.sleep(1)
    
    print("🎉 Demo processing complete!")
    
    # Create summary
    summary = {
        "total_processed": len(urls),
        "success_count": len(urls),
        "container_id": os.environ.get('CONTAINER_ID', 'cloudshell'),
        "processing_time": time.time()
    }
    
    with open(output_dir / "summary.json", 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"📊 Summary saved to {output_dir}/summary.json")
else:
    print(f"❌ URLs file not found: {urls_file}")
PYEOF

ENV PYTHONUNBUFFERED=1
CMD ["python", "entrypoint.py"]
EOF

# 4. Build and push image
echo "🐳 Building Docker image..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI

docker build -t ghost-protocol:cloudshell .
docker tag ghost-protocol:cloudshell $ECR_URI:latest
docker push $ECR_URI:latest

echo "✅ Image pushed to ECR"
```

#### Deploy Kubernetes Jobs
```bash
# 5. Create Kubernetes manifests
echo "🚢 Creating Kubernetes manifests..."

# Create namespace
kubectl create namespace ghost-protocol

# Create ConfigMap for URLs
kubectl create configmap ghost-protocol-urls-1 \
    --from-file=urls_chunk_0001.txt=chunks/urls_chunk_0001.txt \
    --namespace=ghost-protocol

# Create Job
cat > job.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ghost-protocol-cloudshell-demo
  namespace: ghost-protocol
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: ghost-protocol-processor
        image: $ECR_URI:latest
        env:
        - name: CHUNK_ID
          value: "cloudshell-demo"
        - name: URLS_FILE
          value: "/app/data/urls_chunk.txt"
        - name: CONTAINER_ID
          value: "cloudshell-demo"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        volumeMounts:
        - name: urls-volume
          mountPath: /app/data/urls_chunk.txt
          subPath: urls_chunk_0001.txt
      volumes:
      - name: urls-volume
        configMap:
          name: ghost-protocol-urls-1
EOF

# Deploy the job
kubectl apply -f job.yaml

echo "🚀 Job deployed!"
```

### Phase 5: Monitor Progress (Ongoing)

#### Watch Job Progress
```bash
# Check job status
kubectl get jobs -n ghost-protocol

# Check pod status
kubectl get pods -n ghost-protocol

# Get pod name and watch logs
POD_NAME=$(kubectl get pods -n ghost-protocol --no-headers | awk '{print $1}' | head -1)
echo "Pod name: $POD_NAME"

# Follow logs in real-time
kubectl logs -f -n ghost-protocol $POD_NAME
```

#### Advanced Monitoring
```bash
# Create monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "=== Ghost Protocol CloudShell Monitor ==="
echo "Cluster: ghost-protocol"
echo "Region: $AWS_REGION"
echo ""

while true; do
    echo "$(date): Checking job status..."
    
    # Job status
    kubectl get jobs -n ghost-protocol --no-headers | while read job_line; do
        echo "  Job: $job_line"
    done
    
    # Pod status
    kubectl get pods -n ghost-protocol --no-headers | while read pod_line; do
        echo "  Pod: $pod_line"
    done
    
    echo ""
    sleep 30
done
EOF

chmod +x monitor.sh

# Run monitor (Ctrl+C to stop)
./monitor.sh
```

### Phase 6: Collect Results (5 minutes)

#### Extract Results from Pods
```bash
# Get results from completed pod
POD_NAME=$(kubectl get pods -n ghost-protocol --no-headers | awk '{print $1}' | head -1)

echo "📥 Collecting results from pod: $POD_NAME"

# Copy results from pod
kubectl cp ghost-protocol/$POD_NAME:/app/data/output ./results/

# Check what we got
ls -la results/
cat results/summary.json

echo "🎉 Results collected to ./results/ directory"
```

#### Download Results to Local Machine
```bash
# Create results archive
tar -czf ghost-protocol-results.tar.gz results/

echo "📦 Results archived as: ghost-protocol-results.tar.gz"
echo ""
echo "To download:"
echo "1. In CloudShell, click Actions → Download file"
echo "2. Enter: ghost-protocol-results.tar.gz"
echo "3. File will download to your local machine"
```

### Phase 7: Multi-Region Deployment (Optional)

#### Deploy to Multiple Regions
```bash
# Define regions
REGIONS=("us-east-1" "us-west-2" "eu-west-1")

for region in "${REGIONS[@]}"; do
    echo "🌍 Deploying to region: $region"
    
    # Set region context
    export AWS_REGION=$region
    
    # Create cluster in this region
    eksctl create cluster \
        --name ghost-protocol \
        --region $region \
        --node-type t3.medium \
        --nodes 1 \
        --nodes-min 1 \
        --nodes-max 3 \
        --with-oidc \
        --managed &
    
    # Note: Using & to run in background for parallel deployment
done

# Wait for all clusters to be ready
wait

echo "🎉 All regions deployed!"
```

### Phase 8: Cleanup (Important!)

#### Delete Everything
```bash
# Delete jobs first
kubectl delete -f job.yaml

# Delete clusters (important for cost control!)
REGIONS=("us-east-1" "us-west-2" "eu-west-1")

for region in "${REGIONS[@]}"; do
    echo "🗑️ Deleting cluster in $region..."
    eksctl delete cluster --name ghost-protocol --region $region
done

# Delete ECR repositories
for region in "${REGIONS[@]}"; do
    aws ecr delete-repository --repository-name ghost-protocol --region $region --force || true
done

echo "✅ Cleanup complete!"
```

## CloudShell Advantages

### ✅ **Pros:**
- **No local setup** - Everything in browser
- **AWS CLI pre-configured** - Already authenticated
- **Persistent storage** - Files survive between sessions
- **Common tools included** - Docker, git, Python, etc.
- **Free to use** - No additional charges
- **Secure** - Runs in AWS environment

### ⚠️ **Limitations:**
- **Session timeouts** - Sessions expire after 20 minutes of inactivity
- **Compute limits** - Limited CPU/memory for builds
- **Storage limits** - 1GB persistent storage
- **Region availability** - Not available in all regions

## CloudShell vs Other Options

| Method | Setup Time | Learning Curve | Persistence | Cost |
|--------|------------|----------------|-------------|------|
| **CloudShell** | 0 min | Low | Medium | Free |
| **Cloud9** | 2 min | Low | High | $$ |
| **Local CLI** | 15 min | Medium | High | Free |
| **GUI Console** | 0 min | Very Low | High | $$ |

## Tips for CloudShell Success

### 1. **Handle Session Timeouts**
```bash
# Keep session alive with a simple loop
while true; do echo "$(date): Keeping session alive"; sleep 300; done &
```

### 2. **Manage Storage Wisely**
```bash
# Clean up regularly
rm -rf /tmp/*
docker system prune -f

# Check storage usage
df -h $HOME
```

### 3. **Save Important Files**
```bash
# Upload important files to S3
aws s3 cp results/ s3://your-bucket/ghost-protocol-results/ --recursive
```

### 4. **Use Screen for Long Jobs**
```bash
# Install screen for persistent sessions
sudo yum install screen -y

# Start screen session
screen -S ghost-protocol

# Detach: Ctrl+A, then D
# Reattach: screen -r ghost-protocol
```

## Summary

AWS CloudShell provides the perfect balance of convenience and functionality for deploying Ghost Protocol. You get:

- ✅ **Zero setup** - Just open browser and start
- ✅ **Full AWS integration** - Pre-authenticated and configured
- ✅ **Professional tools** - kubectl, eksctl, Docker, AWS CLI
- ✅ **Cost effective** - Free CloudShell, pay only for AWS resources
- ✅ **Secure** - Runs in your AWS environment

Perfect for quick deployments, testing, and learning Kubernetes! 🌐🚀