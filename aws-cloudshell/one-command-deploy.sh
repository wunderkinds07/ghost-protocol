#!/bin/bash
# One-command deployment for Ghost Protocol in AWS CloudShell
# Usage: curl -s https://raw.githubusercontent.com/your-repo/ghost-protocol/main/aws-cloudshell/one-command-deploy.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Ghost Protocol One-Command CloudShell Deploy${NC}"
echo ""

# Check if we're in CloudShell
if [[ "$USER" != "cloudshell-user" ]]; then
    echo -e "${YELLOW}⚠️  This script is optimized for AWS CloudShell${NC}"
    echo "You can still run it, but some features may not work as expected."
    echo ""
fi

# Get AWS info
AWS_REGION=$(aws configure get region || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME="ghost-protocol-$(date +%s)"

echo "🔧 Configuration:"
echo "  Account: $ACCOUNT_ID"
echo "  Region: $AWS_REGION"  
echo "  Cluster: $CLUSTER_NAME"
echo ""

# Step 1: Install tools
echo -e "${YELLOW}Step 1: Installing required tools...${NC}"

install_tool() {
    local tool=$1
    local install_cmd=$2
    
    if ! command -v $tool &> /dev/null; then
        echo "Installing $tool..."
        eval $install_cmd
        echo "✅ $tool installed"
    else
        echo "✅ $tool already available"
    fi
}

install_tool "eksctl" 'curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin'
install_tool "kubectl" 'curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl'

# Step 2: Create project
echo ""
echo -e "${YELLOW}Step 2: Setting up project...${NC}"

mkdir -p ghost-protocol-deploy && cd ghost-protocol-deploy

# Create sample URLs
cat > urls.txt << 'EOF'
https://www.1stdibs.com/furniture/seating/benches/mid-century-modern-wooden-bench-unknown-danish-cabinetmaker-1960s/id-f_31310552/
https://www.1stdibs.com/furniture/seating/chairs/mid-century-modern-stacking-chairs-verner-panton-herman-miller-1960s/id-f_1234567/
https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-modern-dining-table-carlo-scarpa-1970s/id-f_2345678/
https://www.1stdibs.com/furniture/storage-case-pieces/cabinets/danish-modern-teak-cabinet-arne-vodder-1960s/id-f_3456789/
https://www.1stdibs.com/furniture/lighting/floor-lamps/italian-arc-floor-lamp-achille-castiglioni-flos-1962/id-f_4567890/
EOF

echo "📁 Created project with $(wc -l < urls.txt) sample URLs"

# Create Dockerfile with all-in-one processor
cat > Dockerfile << 'EOF'
FROM python:3.9-slim
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN pip install requests beautifulsoup4 lxml tqdm
WORKDIR /app
COPY processor.py .
CMD ["python", "processor.py"]
EOF

# Create simplified processor
cat > processor.py << 'EOF'
#!/usr/bin/env python3
import os, json, time, hashlib
from datetime import datetime
from pathlib import Path

def process_urls():
    print("🚀 Ghost Protocol One-Command Demo")
    print(f"🆔 Container: {os.environ.get('HOSTNAME', 'cloudshell')}")
    
    urls_file = os.environ.get('URLS_FILE', '/app/urls.txt')
    output_dir = Path('/app/output')
    output_dir.mkdir(exist_ok=True)
    
    if not os.path.exists(urls_file):
        print(f"❌ URLs file not found: {urls_file}")
        return
    
    with open(urls_file, 'r') as f:
        urls = [line.strip() for line in f if line.strip()]
    
    print(f"📊 Processing {len(urls)} URLs")
    results = []
    
    for i, url in enumerate(urls, 1):
        print(f"🔄 [{i}/{len(urls)}] {url}")
        
        product_id = hashlib.md5(url.encode()).hexdigest()[:8]
        result = {
            "url": url,
            "product_id": product_id,
            "title": f"Demo Product {i}",
            "category": "Furniture",
            "price": f"${(hash(url) % 5000 + 500):,}",
            "extracted_at": datetime.now().isoformat(),
            "demo": True
        }
        
        results.append(result)
        
        # Save individual result
        with open(output_dir / f"{product_id}.json", 'w') as f:
            json.dump(result, f, indent=2)
        
        print(f"  ✅ {result['title']} - {result['price']}")
        time.sleep(0.5)
    
    # Save summary
    summary = {
        "total_processed": len(results),
        "processing_time": datetime.now().isoformat(),
        "container": os.environ.get('HOSTNAME', 'cloudshell'),
        "demo_mode": True,
        "products": results
    }
    
    with open(output_dir / 'summary.json', 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"🎉 Complete! Processed {len(results)} URLs")
    print(f"📁 Results: {output_dir}")

if __name__ == "__main__":
    process_urls()
EOF

echo "✅ Application files created"

# Step 3: Create and setup EKS cluster
echo ""
echo -e "${YELLOW}Step 3: Creating EKS cluster (15-20 minutes)...${NC}"
echo "☕ This is a good time for a coffee break!"

eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $AWS_REGION \
    --node-type t3.small \
    --nodes 1 \
    --nodes-min 1 \
    --nodes-max 3 \
    --managed \
    --timeout 25m

echo "✅ EKS cluster created!"

# Step 4: Build and push image
echo ""
echo -e "${YELLOW}Step 4: Building Docker image...${NC}"

# Create ECR repository
aws ecr create-repository --repository-name ghost-protocol-demo --region $AWS_REGION 2>/dev/null || echo "Repository exists"

ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ghost-protocol-demo"
echo "📦 ECR URI: $ECR_URI"

# Login and build
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI
docker build -t ghost-protocol-demo .
docker tag ghost-protocol-demo:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "✅ Image pushed to ECR"

# Step 5: Deploy to Kubernetes
echo ""
echo -e "${YELLOW}Step 5: Deploying to Kubernetes...${NC}"

# Create namespace
kubectl create namespace ghost-protocol

# Create ConfigMap with URLs
kubectl create configmap urls-config --from-file=urls.txt --namespace=ghost-protocol

# Create and deploy job
cat > job.yaml << EOF
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
      - name: processor
        image: $ECR_URI:latest
        env:
        - name: URLS_FILE
          value: /app/urls.txt
        volumeMounts:
        - name: urls
          mountPath: /app/urls.txt
          subPath: urls.txt
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: urls
        configMap:
          name: urls-config
EOF

kubectl apply -f job.yaml

echo "✅ Job deployed to Kubernetes"

# Step 6: Monitor and collect results
echo ""
echo -e "${YELLOW}Step 6: Monitoring job...${NC}"

echo "⏳ Waiting for job to start..."
kubectl wait --for=condition=ready pod -l job-name=ghost-protocol-demo -n ghost-protocol --timeout=300s

POD_NAME=$(kubectl get pods -n ghost-protocol -l job-name=ghost-protocol-demo --no-headers | awk '{print $1}')
echo "📱 Pod started: $POD_NAME"

echo ""
echo "📋 Live logs:"
kubectl logs -f -n ghost-protocol $POD_NAME

echo ""
echo -e "${YELLOW}Step 7: Collecting results...${NC}"

# Wait for completion
kubectl wait --for=condition=complete job/ghost-protocol-demo -n ghost-protocol --timeout=600s

# Copy results
mkdir -p results
kubectl cp ghost-protocol/$POD_NAME:/app/output/ results/ 2>/dev/null || echo "Results may be empty"

# Show results
if [ -f "results/summary.json" ]; then
    echo ""
    echo "📊 Processing Summary:"
    cat results/summary.json | jq -r '"Total processed: \(.total_processed)"'
    cat results/summary.json | jq -r '"Processing time: \(.processing_time)"'
    echo ""
    echo "📄 Individual results:"
    ls -la results/*.json | wc -l | awk '{print "  " $1 " files created"}'
else
    echo "⚠️  No summary found, checking pod logs for results"
fi

# Create downloadable archive
echo ""
echo -e "${YELLOW}Step 8: Creating download package...${NC}"

tar -czf ghost-protocol-results.tar.gz results/ *.yaml *.py Dockerfile urls.txt

echo "📦 Results packaged: ghost-protocol-results.tar.gz"
echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo ""
echo "📋 Summary:"
echo "  ✅ EKS cluster created: $CLUSTER_NAME"
echo "  ✅ Docker image built and pushed"
echo "  ✅ Kubernetes job deployed and completed"
echo "  ✅ Results collected and packaged"
echo ""
echo "📥 To download results:"
echo "  1. In CloudShell: Actions → Download file"
echo "  2. Enter: ghost-protocol-results.tar.gz"
echo ""
echo "🗑️  To cleanup (save costs):"
echo "  eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION"
echo ""
echo "🎯 Next steps:"
echo "  • Replace urls.txt with your actual URLs"
echo "  • Scale up with more nodes for larger datasets"
echo "  • Customize processor.py for your data extraction needs"

# Save cleanup command
echo "eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION" > cleanup-cluster.sh
chmod +x cleanup-cluster.sh

echo ""
echo "🚀 Ghost Protocol deployment successful!"
echo "Run ./cleanup-cluster.sh when done to delete the cluster."