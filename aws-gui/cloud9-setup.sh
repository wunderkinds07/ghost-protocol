#!/bin/bash
# Script to run in AWS Cloud9 for complete Ghost Protocol setup

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Ghost Protocol Setup in AWS Cloud9 ===${NC}"
echo "This script will set up everything needed for Ghost Protocol in Cloud9"
echo ""

# Get AWS info
REGION=$(aws configure get region || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# Step 1: Install required tools
echo -e "${YELLOW}Step 1: Installing required tools...${NC}"

# Install eksctl
if ! command -v eksctl &> /dev/null; then
    echo "Installing eksctl..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    echo "✅ eksctl installed"
else
    echo "✅ eksctl already installed"
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo "✅ kubectl installed"
else
    echo "✅ kubectl already installed"
fi

# Install helm
if ! command -v helm &> /dev/null; then
    echo "Installing helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ helm installed"
else
    echo "✅ helm already installed"
fi

# Step 2: Create project structure
echo -e "${YELLOW}Step 2: Creating Ghost Protocol project structure...${NC}"

mkdir -p ghost-protocol/{src/{parsers,extractors},docker,k8s,chunks}
cd ghost-protocol

# Create essential files
echo "Creating Dockerfile..."
cat > Dockerfile << 'EOF'
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY docker/entrypoint.py .
COPY docker/notifier.py .
COPY docker/s3_uploader.py .

# Create data directories
RUN mkdir -p /app/data/output /app/data/logs

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV CONTAINER_ID=cloud9-test
ENV URL_CHUNK_START=0
ENV URL_CHUNK_SIZE=5000

# Health check script
RUN echo '#!/bin/bash\ntouch /app/data/output/alive.txt\necho "$(date): Pod alive" >> /app/data/output/health.log' > /app/health.sh && chmod +x /app/health.sh

CMD ["python", "entrypoint.py"]
EOF

echo "Creating requirements.txt..."
cat > requirements.txt << 'EOF'
requests==2.32.3
beautifulsoup4==4.13.4
lxml==5.4.0
tqdm>=4.65.0
pandas==2.2.3
numpy==1.26.4
pytz>=2023.3
python-dateutil>=2.8.2
EOF

echo "Creating sample source files..."
mkdir -p src/parsers src/extractors docker

# Create minimal entrypoint
cat > docker/entrypoint.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import json
import time
from pathlib import Path

print("🚀 Ghost Protocol starting in Cloud9...")
print(f"Container ID: {os.environ.get('CONTAINER_ID', 'unknown')}")

# Simple test processing
urls_file = os.environ.get('URLS_FILE', '/app/data/urls_chunk.txt')
if os.path.exists(urls_file):
    with open(urls_file, 'r') as f:
        urls = [line.strip() for line in f if line.strip()]
    print(f"📁 Found {len(urls)} URLs to process")
    
    # Create output directory
    output_dir = Path('/app/data/output')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Simulate processing
    for i, url in enumerate(urls[:5], 1):  # Process first 5 for demo
        print(f"🔄 Processing {i}/{len(urls)}: {url}")
        
        # Simulate extraction
        result = {
            "url": url,
            "processed_at": time.time(),
            "status": "success",
            "demo_data": {
                "title": f"Demo Product {i}",
                "description": "This is a demo extraction result"
            }
        }
        
        # Save result
        output_file = output_dir / f"result_{i:04d}.json"
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2)
        
        print(f"✅ Saved: {output_file}")
        time.sleep(2)  # Simulate processing time
    
    print("🎉 Processing complete!")
else:
    print(f"❌ URLs file not found: {urls_file}")
    print("Creating sample URLs file...")
    
    # Create sample URLs
    sample_urls = [
        "https://www.1stdibs.com/furniture/seating/benches/mid-century-modern-wooden-bench-unknown-danish-cabinetmaker-1960s/id-f_31310552/",
        "https://www.1stdibs.com/furniture/seating/chairs/mid-century-modern-stacking-chairs-verner-panton-herman-miller-1960s/id-f_1234567/",
        "https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-modern-dining-table-carlo-scarpa-1970s/id-f_2345678/"
    ]
    
    os.makedirs(os.path.dirname(urls_file), exist_ok=True)
    with open(urls_file, 'w') as f:
        for url in sample_urls:
            f.write(url + '\n')
    
    print(f"✅ Created sample URLs file: {urls_file}")
    print("Please re-run to process the sample URLs")
EOF

# Create dummy notifier and s3_uploader
cat > docker/notifier.py << 'EOF'
def notify_start(url_count):
    print(f"📢 Starting processing of {url_count} URLs")

def notify_progress(current, total, success, failed):
    print(f"📊 Progress: {current}/{total} ({current/total*100:.1f}%)")

def notify_complete(summary):
    print(f"🎉 Processing complete: {summary}")

def notify_error(error):
    print(f"❌ Error: {error}")

def notify_warning(warning):
    print(f"⚠️ Warning: {warning}")

def notify_milestone(count):
    print(f"🎯 Milestone reached: {count} URLs processed")
EOF

cat > docker/s3_uploader.py << 'EOF'
class S3Uploader:
    def upload_raw_html(self, product_id, file_path):
        print(f"📤 [S3] Would upload HTML: {product_id}")
    
    def upload_extracted_data(self, product_id, file_path):
        print(f"📤 [S3] Would upload JSON: {product_id}")
    
    def upload_summary(self, file_path):
        print(f"📤 [S3] Would upload summary: {file_path}")

def get_s3_uploader():
    return S3Uploader()
EOF

# Create sample URLs
echo "Creating sample URL chunks..."
cat > chunks/urls_chunk_0001.txt << 'EOF'
https://www.1stdibs.com/furniture/seating/benches/mid-century-modern-wooden-bench-unknown-danish-cabinetmaker-1960s/id-f_31310552/
https://www.1stdibs.com/furniture/seating/chairs/mid-century-modern-stacking-chairs-verner-panton-herman-miller-1960s/id-f_1234567/
https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-modern-dining-table-carlo-scarpa-1970s/id-f_2345678/
https://www.1stdibs.com/furniture/storage-case-pieces/cabinets/danish-modern-teak-cabinet-arne-vodder-1960s/id-f_3456789/
https://www.1stdibs.com/furniture/lighting/floor-lamps/italian-arc-floor-lamp-achille-castiglioni-flos-1962/id-f_4567890/
EOF

# Step 3: Create ECR repository
echo -e "${YELLOW}Step 3: Creating ECR repository...${NC}"
aws ecr create-repository --repository-name ghost-protocol --region $REGION 2>/dev/null || echo "Repository already exists"

ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ghost-protocol"
echo "ECR URI: $ECR_URI"

# Step 4: Build and push Docker image
echo -e "${YELLOW}Step 4: Building and pushing Docker image...${NC}"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Build image
echo "Building Docker image..."
docker build -t ghost-protocol:latest .

# Tag and push
echo "Tagging and pushing image..."
docker tag ghost-protocol:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "✅ Image pushed to: $ECR_URI:latest"

# Step 5: Test locally
echo -e "${YELLOW}Step 5: Testing Docker image locally...${NC}"

echo "Running test container..."
docker run --rm \
  -v "$(pwd)/chunks/urls_chunk_0001.txt:/app/data/urls_chunk.txt:ro" \
  -e URLS_FILE=/app/data/urls_chunk.txt \
  -e CONTAINER_ID=cloud9-local-test \
  $ECR_URI:latest

# Step 6: Create Kubernetes manifests
echo -e "${YELLOW}Step 6: Creating Kubernetes manifests...${NC}"

# Namespace
cat > k8s/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: ghost-protocol
  labels:
    name: ghost-protocol
EOF

# ConfigMap for URLs
cat > k8s/urls-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ghost-protocol-urls-1
  namespace: ghost-protocol
data:
  urls_chunk_0001.txt: |
$(cat chunks/urls_chunk_0001.txt | sed 's/^/    /')
EOF

# Job template
cat > k8s/job.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ghost-protocol-demo
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
          value: "1"
        - name: URLS_FILE
          value: "/app/data/urls_chunk.txt"
        - name: CONTAINER_ID
          value: "cloud9-k8s-demo"
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

# Step 7: Instructions for EKS deployment
echo -e "${YELLOW}Step 7: Next steps for EKS deployment...${NC}"

cat > DEPLOY_TO_EKS.md << EOF
# Deploy to EKS from Cloud9

## Option 1: Create EKS cluster and deploy

\`\`\`bash
# Create EKS cluster (takes 15-20 minutes)
eksctl create cluster \\
  --name ghost-protocol \\
  --region $REGION \\
  --node-type t3.medium \\
  --nodes 2 \\
  --nodes-min 1 \\
  --nodes-max 5

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name ghost-protocol

# Deploy namespace and configmap
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/urls-configmap.yaml

# Deploy job
kubectl apply -f k8s/job.yaml

# Monitor progress
kubectl get jobs -n ghost-protocol
kubectl get pods -n ghost-protocol
kubectl logs -f -n ghost-protocol <pod-name>
\`\`\`

## Option 2: Use existing cluster

\`\`\`bash
# Update kubeconfig for existing cluster
aws eks update-kubeconfig --region $REGION --name YOUR_CLUSTER_NAME

# Deploy
kubectl apply -f k8s/
\`\`\`

## Clean up

\`\`\`bash
# Delete job
kubectl delete -f k8s/job.yaml

# Delete cluster (when done)
eksctl delete cluster --name ghost-protocol --region $REGION
\`\`\`
EOF

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "📁 Project created in: $(pwd)"
echo "🐳 Docker image: $ECR_URI:latest"
echo "📋 Next steps in: DEPLOY_TO_EKS.md"
echo ""
echo "Quick commands:"
echo "  📖 View deployment guide: cat DEPLOY_TO_EKS.md"
echo "  🚀 Create EKS cluster: eksctl create cluster --name ghost-protocol --region $REGION --node-type t3.medium --nodes 2"
echo "  🔍 Monitor jobs: kubectl get jobs -n ghost-protocol"
echo ""
echo "🎉 Ready to deploy to EKS!"