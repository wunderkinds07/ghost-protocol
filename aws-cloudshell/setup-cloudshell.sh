#!/bin/bash
# Complete setup script for Ghost Protocol in AWS CloudShell

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Ghost Protocol CloudShell Setup ===${NC}"
echo "Setting up complete Ghost Protocol environment in AWS CloudShell"
echo ""

# Get AWS info
AWS_REGION=$(aws configure get region || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Account ID: $ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

# Check if we're in CloudShell
if [[ "$USER" == "cloudshell-user" ]]; then
    echo -e "${GREEN}✅ Running in AWS CloudShell${NC}"
else
    echo -e "${YELLOW}⚠️  Not running in CloudShell, but continuing...${NC}"
fi

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

# Verify installations
echo ""
echo "Tool versions:"
echo "  AWS CLI: $(aws --version)"
echo "  Docker: $(docker --version)"
echo "  kubectl: $(kubectl version --client --short)"
echo "  eksctl: $(eksctl version)"
echo "  Helm: $(helm version --short)"

# Step 2: Create project structure
echo ""
echo -e "${YELLOW}Step 2: Creating Ghost Protocol project...${NC}"

# Create directory structure
mkdir -p ghost-protocol/{chunks,k8s,scripts,results}
cd ghost-protocol

# Create sample URLs
echo "Creating sample URLs..."
cat > sample-urls.txt << 'EOF'
https://www.1stdibs.com/furniture/seating/benches/mid-century-modern-wooden-bench-unknown-danish-cabinetmaker-1960s/id-f_31310552/
https://www.1stdibs.com/furniture/seating/chairs/mid-century-modern-stacking-chairs-verner-panton-herman-miller-1960s/id-f_1234567/
https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-modern-dining-table-carlo-scarpa-1970s/id-f_2345678/
https://www.1stdibs.com/furniture/storage-case-pieces/cabinets/danish-modern-teak-cabinet-arne-vodder-1960s/id-f_3456789/
https://www.1stdibs.com/furniture/lighting/floor-lamps/italian-arc-floor-lamp-achille-castiglioni-flos-1962/id-f_4567890/
https://www.1stdibs.com/furniture/seating/sofas/scandinavian-modern-sofa-finn-juhl-1950s/id-f_5678901/
https://www.1stdibs.com/furniture/tables/coffee-tables-cocktail-tables/glass-coffee-table-isamu-noguchi-herman-miller/id-f_6789012/
https://www.1stdibs.com/furniture/seating/lounge-chairs/barcelona-chair-mies-van-der-rohe-knoll-1929/id-f_7890123/
https://www.1stdibs.com/furniture/storage-case-pieces/desks/executive-desk-george-nelson-herman-miller-1960s/id-f_8901234/
https://www.1stdibs.com/furniture/lighting/chandeliers-pendant-lights/murano-glass-chandelier-venini-1970s/id-f_9012345/
EOF

# Create URL chunks
echo "Creating URL chunks..."
python3 << 'PYEOF'
import os

urls_file = 'sample-urls.txt'
chunk_size = 5
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

print('✅ URL chunks created')
PYEOF

# Step 3: Create Docker image
echo ""
echo -e "${YELLOW}Step 3: Creating Docker image...${NC}"

cat > Dockerfile << 'EOF'
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python packages
RUN pip install --no-cache-dir \
    requests==2.32.3 \
    beautifulsoup4==4.13.4 \
    lxml==5.4.0 \
    tqdm>=4.65.0 \
    pandas==2.2.3 \
    numpy==1.26.4

# Create application
COPY entrypoint.py .
RUN chmod +x entrypoint.py

# Create data directories
RUN mkdir -p /app/data/output /app/data/logs

ENV PYTHONUNBUFFERED=1
CMD ["python", "entrypoint.py"]
EOF

# Create entrypoint script
cat > entrypoint.py << 'EOF'
#!/usr/bin/env python3
"""
Ghost Protocol CloudShell Demo Processor
Simulates the full Ghost Protocol data extraction pipeline
"""

import os
import sys
import json
import time
import requests
from pathlib import Path
from datetime import datetime
import hashlib

def extract_product_id(url):
    """Extract product ID from URL"""
    if '/id-f_' in url:
        parts = url.split('/id-f_')[1]
        product_id = 'f_' + parts.split('/')[0]
        return product_id
    else:
        return hashlib.md5(url.encode()).hexdigest()[:10]

def simulate_extraction(url):
    """Simulate product data extraction"""
    product_id = extract_product_id(url)
    
    # Simulate different product types based on URL
    if 'seating' in url:
        category = 'Furniture > Seating'
        if 'chairs' in url:
            subcategory = 'Chairs'
        elif 'sofas' in url:
            subcategory = 'Sofas'
        else:
            subcategory = 'Benches'
    elif 'tables' in url:
        category = 'Furniture > Tables'
        subcategory = 'Dining Tables' if 'dining' in url else 'Coffee Tables'
    elif 'lighting' in url:
        category = 'Furniture > Lighting'
        subcategory = 'Floor Lamps' if 'floor-lamps' in url else 'Chandeliers'
    else:
        category = 'Furniture > Storage'
        subcategory = 'Cabinets'
    
    # Simulate extracted data
    return {
        "url": url,
        "extraction_status": "success",
        "data": {
            "product_info": {
                "title": f"Demo {subcategory} Item",
                "description": f"This is a simulated extraction for a {subcategory.lower()} item from 1stDibs marketplace. In real processing, this would contain the actual product description extracted from the HTML.",
                "product_id": product_id,
                "brand": "Demo Brand"
            },
            "specifications": {
                "period": "1960-1970",
                "category": subcategory,
                "condition": "Good",
                "materials": ["Wood", "Metal"] if 'modern' in url else ["Fabric", "Wood"]
            },
            "pricing": {
                "current_price": f"${(hash(url) % 5000 + 1000):,}",
                "currency": "USD"
            },
            "images": [
                f"https://demo.1stdibs.com/image1_{product_id}.jpg",
                f"https://demo.1stdibs.com/image2_{product_id}.jpg",
                f"https://demo.1stdibs.com/image3_{product_id}.jpg"
            ],
            "category_breadcrumb": [
                "Home",
                "Furniture",
                category.split(' > ')[1],
                subcategory
            ]
        },
        "extraction_metadata": {
            "container_id": os.environ.get('CONTAINER_ID', 'cloudshell'),
            "extraction_time": datetime.now().isoformat(),
            "processing_method": "cloudshell_demo",
            "html_size_bytes": hash(url) % 100000 + 50000
        }
    }

def main():
    print("🚀 Ghost Protocol CloudShell Demo Processor")
    print(f"Container ID: {os.environ.get('CONTAINER_ID', 'cloudshell')}")
    print(f"Start time: {datetime.now()}")
    print("")
    
    # Setup paths
    urls_file = os.environ.get('URLS_FILE', '/app/data/urls_chunk.txt')
    output_dir = Path('/app/data/output')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Load URLs
    if not os.path.exists(urls_file):
        print(f"❌ URLs file not found: {urls_file}")
        return False
    
    with open(urls_file, 'r') as f:
        urls = [line.strip() for line in f if line.strip()]
    
    print(f"📁 Found {len(urls)} URLs to process")
    print("")
    
    # Process URLs
    results = []
    start_time = time.time()
    
    for i, url in enumerate(urls, 1):
        print(f"🔄 Processing {i}/{len(urls)}: {url}")
        
        try:
            # Simulate processing time
            time.sleep(0.5)
            
            # Extract data
            extracted_data = simulate_extraction(url)
            results.append(extracted_data)
            
            # Save individual result
            product_id = extracted_data['data']['product_info']['product_id']
            result_file = output_dir / f"{product_id}.json"
            
            with open(result_file, 'w') as f:
                json.dump(extracted_data, f, indent=2)
            
            print(f"  ✅ Extracted: {extracted_data['data']['product_info']['title']}")
            print(f"  💰 Price: {extracted_data['data']['pricing']['current_price']}")
            print(f"  📂 Category: {extracted_data['data']['specifications']['category']}")
            print(f"  💾 Saved: {result_file}")
            print("")
            
        except Exception as e:
            print(f"  ❌ Error processing {url}: {str(e)}")
            print("")
    
    # Create summary
    processing_time = time.time() - start_time
    summary = {
        "container_id": os.environ.get('CONTAINER_ID', 'cloudshell'),
        "processing_time": datetime.now().isoformat(),
        "urls_processed": len(urls),
        "successful": len(results),
        "failed": len(urls) - len(results),
        "processing_seconds": processing_time,
        "urls_per_minute": (len(urls) / processing_time * 60) if processing_time > 0 else 0,
        "demo_mode": True
    }
    
    summary_file = output_dir / "processing_summary.json"
    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    # Create merged results file
    merged_file = output_dir / "all_extracted_products.json"
    with open(merged_file, 'w') as f:
        json.dump({
            "total_products": len(results),
            "summary": summary,
            "products": results
        }, f, indent=2)
    
    print("🎉 Processing Complete!")
    print(f"📊 Processed: {len(urls)} URLs")
    print(f"✅ Successful: {len(results)}")
    print(f"⏱️  Time: {processing_time:.1f} seconds")
    print(f"🚀 Rate: {summary['urls_per_minute']:.1f} URLs/minute")
    print(f"📁 Results saved to: {output_dir}")
    print(f"📄 Summary: {summary_file}")
    print(f"📦 Merged data: {merged_file}")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF

echo "✅ Docker files created"

# Step 4: Create Kubernetes manifests
echo ""
echo -e "${YELLOW}Step 4: Creating Kubernetes manifests...${NC}"

# Namespace
cat > k8s/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: ghost-protocol
  labels:
    name: ghost-protocol
    created-by: cloudshell
EOF

# ConfigMap for settings
cat > k8s/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: ghost-protocol-config
  namespace: ghost-protocol
data:
  PROCESSING_MODE: "demo"
  LOG_LEVEL: "INFO"
  OUTPUT_FORMAT: "json"
EOF

# Job template
cat > k8s/job-template.yaml << 'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: ghost-protocol-CHUNK_ID
  namespace: ghost-protocol
  labels:
    app: ghost-protocol
    chunk-id: "CHUNK_ID"
    created-by: cloudshell
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: ghost-protocol
        chunk-id: "CHUNK_ID"
    spec:
      restartPolicy: Never
      containers:
      - name: ghost-protocol-processor
        image: ECR_URI_PLACEHOLDER
        env:
        - name: CHUNK_ID
          value: "CHUNK_ID"
        - name: URLS_FILE
          value: "/app/data/urls_chunk.txt"
        - name: CONTAINER_ID
          value: "cloudshell-CHUNK_ID"
        envFrom:
        - configMapRef:
            name: ghost-protocol-config
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: urls-volume
          mountPath: /app/data/urls_chunk.txt
          subPath: CHUNK_FILE
      volumes:
      - name: urls-volume
        configMap:
          name: ghost-protocol-urls-CHUNK_ID
EOF

echo "✅ Kubernetes manifests created"

# Step 5: Create deployment scripts
echo ""
echo -e "${YELLOW}Step 5: Creating deployment scripts...${NC}"

# Quick deploy script
cat > scripts/quick-deploy.sh << 'EOF'
#!/bin/bash
# Quick deployment script for CloudShell

set -e

CLUSTER_NAME=${1:-ghost-protocol}
REGION=${2:-$(aws configure get region)}

echo "🚀 Quick Deploy to EKS"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

# Create EKS cluster
echo "Creating EKS cluster (15-20 minutes)..."
eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 1 \
    --nodes-max 5 \
    --managed

echo "✅ Cluster created!"

# Build and deploy
echo "Building and deploying application..."
bash scripts/build-and-deploy.sh $CLUSTER_NAME $REGION

echo "🎉 Deployment complete!"
EOF

# Build and deploy script
cat > scripts/build-and-deploy.sh << 'EOF'
#!/bin/bash
# Build Docker image and deploy to Kubernetes

set -e

CLUSTER_NAME=${1:-ghost-protocol}
REGION=${2:-$(aws configure get region)}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🐳 Building and deploying Ghost Protocol"
echo ""

# Create ECR repository
aws ecr create-repository --repository-name ghost-protocol --region $REGION 2>/dev/null || echo "Repository exists"

# Get ECR URI
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ghost-protocol"
echo "ECR URI: $ECR_URI"

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Build image
echo "Building Docker image..."
docker build -t ghost-protocol:cloudshell .

# Tag and push
docker tag ghost-protocol:cloudshell $ECR_URI:latest
docker push $ECR_URI:latest

echo "✅ Image pushed to ECR"

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Deploy namespace and config
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml

# Create ConfigMaps for URL chunks
echo "Creating URL ConfigMaps..."
for chunk_file in chunks/urls_chunk_*.txt; do
    if [ -f "$chunk_file" ]; then
        chunk_name=$(basename "$chunk_file" .txt)
        chunk_id=$(echo "$chunk_name" | sed 's/urls_chunk_//')
        
        kubectl create configmap "ghost-protocol-urls-$chunk_id" \
            --from-file="$chunk_file" \
            --namespace=ghost-protocol \
            --dry-run=client -o yaml | kubectl apply -f -
        
        echo "  Created ConfigMap for chunk $chunk_id"
    fi
done

# Deploy jobs
echo "Deploying processing jobs..."
for chunk_file in chunks/urls_chunk_*.txt; do
    if [ -f "$chunk_file" ]; then
        chunk_name=$(basename "$chunk_file" .txt)
        chunk_id=$(echo "$chunk_name" | sed 's/urls_chunk_//')
        
        # Create job from template
        sed -e "s/CHUNK_ID/$chunk_id/g" \
            -e "s/ECR_URI_PLACEHOLDER/$ECR_URI:latest/g" \
            -e "s/CHUNK_FILE/$chunk_name.txt/g" \
            k8s/job-template.yaml > /tmp/job-$chunk_id.yaml
        
        kubectl apply -f /tmp/job-$chunk_id.yaml
        rm /tmp/job-$chunk_id.yaml
        
        echo "  Deployed job for chunk $chunk_id"
    fi
done

echo "🚀 All jobs deployed!"
EOF

# Monitor script
cat > scripts/monitor.sh << 'EOF'
#!/bin/bash
# Monitor Ghost Protocol jobs

CLUSTER_NAME=${1:-ghost-protocol}
REGION=${2:-$(aws configure get region)}

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

echo "=== Ghost Protocol CloudShell Monitor ==="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

while true; do
    echo "$(date): Job Status"
    kubectl get jobs -n ghost-protocol --no-headers | awk '{
        if ($2 == "1/1") completed++
        else if ($3 > 0) running++
        else pending++
        total++
    }
    END {
        print "  Total: " total ", Completed: " completed ", Running: " running ", Pending: " pending
    }'
    
    echo ""
    echo "Recent jobs:"
    kubectl get jobs -n ghost-protocol | head -6
    
    echo ""
    echo "Running pods:"
    kubectl get pods -n ghost-protocol --field-selector status.phase=Running | head -3
    
    echo ""
    echo "----------------------------------------"
    sleep 30
done
EOF

# Collect results script
cat > scripts/collect-results.sh << 'EOF'
#!/bin/bash
# Collect results from all completed jobs

CLUSTER_NAME=${1:-ghost-protocol}
REGION=${2:-$(aws configure get region)}

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

echo "📥 Collecting results from Ghost Protocol jobs"
echo ""

# Create results directory
mkdir -p results
cd results

# Get all completed jobs
COMPLETED_JOBS=$(kubectl get jobs -n ghost-protocol --no-headers | awk '$2 == "1/1" {print $1}')

if [ -z "$COMPLETED_JOBS" ]; then
    echo "No completed jobs found"
    exit 0
fi

echo "Found completed jobs:"
echo "$COMPLETED_JOBS"
echo ""

# Collect from each job
for job in $COMPLETED_JOBS; do
    echo "Collecting from job: $job"
    
    # Get pod name
    pod=$(kubectl get pods -n ghost-protocol --selector=job-name=$job --no-headers | awk '{print $1}')
    
    if [ -n "$pod" ]; then
        # Create job directory
        mkdir -p $job
        
        # Copy results
        kubectl cp ghost-protocol/$pod:/app/data/output/ $job/ || echo "  Failed to copy results"
        
        # Get logs
        kubectl logs -n ghost-protocol $pod > $job/pod.log || echo "  Failed to copy logs"
        
        echo "  ✅ Collected results for $job"
    else
        echo "  ❌ No pod found for $job"
    fi
done

# Create combined results
echo ""
echo "📊 Creating combined results..."

# Merge all JSON files
python3 << 'PYEOF'
import json
import os
import glob

all_products = []
total_stats = {
    "total_jobs": 0,
    "total_urls": 0,
    "total_products": 0
}

for job_dir in glob.glob("ghost-protocol-*"):
    if os.path.isdir(job_dir):
        total_stats["total_jobs"] += 1
        
        # Look for merged results file
        merged_file = os.path.join(job_dir, "all_extracted_products.json")
        if os.path.exists(merged_file):
            with open(merged_file, 'r') as f:
                data = json.load(f)
                all_products.extend(data.get("products", []))
                total_stats["total_products"] += data.get("total_products", 0)

# Save combined results
combined_results = {
    "collection_summary": total_stats,
    "total_products": len(all_products),
    "products": all_products
}

with open("combined_results.json", 'w') as f:
    json.dump(combined_results, f, indent=2)

print(f"✅ Combined {len(all_products)} products from {total_stats['total_jobs']} jobs")
print("📄 Results saved to: combined_results.json")
PYEOF

echo ""
echo "🎉 Results collection complete!"
echo "📁 Results directory: $(pwd)"
echo "📄 Combined results: combined_results.json"
echo ""
echo "To download results:"
echo "1. Create archive: tar -czf results.tar.gz *"
echo "2. In CloudShell: Actions → Download file → results.tar.gz"
EOF

# Make scripts executable
chmod +x scripts/*.sh

echo "✅ Scripts created"

# Step 6: Create quick start guide
echo ""
echo -e "${YELLOW}Step 6: Creating quick start guide...${NC}"

cat > CLOUDSHELL_QUICKSTART.md << 'EOF'
# Ghost Protocol CloudShell Quick Start

## 🚀 One-Command Deployment

```bash
# Deploy everything (takes 20-25 minutes)
bash scripts/quick-deploy.sh
```

## 📊 Monitor Progress

```bash
# Watch job progress
bash scripts/monitor.sh

# Check specific jobs
kubectl get jobs -n ghost-protocol
kubectl get pods -n ghost-protocol

# View logs
kubectl logs -f -n ghost-protocol <pod-name>
```

## 📥 Collect Results

```bash
# Collect all results
bash scripts/collect-results.sh

# Download results
cd results
tar -czf results.tar.gz *
# Then: Actions → Download file → results.tar.gz
```

## 🗑️ Cleanup

```bash
# Delete jobs
kubectl delete jobs --all -n ghost-protocol

# Delete cluster (important!)
eksctl delete cluster --name ghost-protocol --region us-east-1
```

## 📁 Project Structure

```
ghost-protocol/
├── chunks/              # URL chunks (5 URLs each)
├── k8s/                # Kubernetes manifests
├── scripts/            # Deployment scripts
├── results/            # Collected results
├── Dockerfile          # Container definition
├── entrypoint.py       # Processing logic
└── sample-urls.txt     # Test URLs
```

## 🎯 What Happens

1. **Creates EKS cluster** (15-20 min)
2. **Builds Docker image** with demo processor
3. **Deploys Kubernetes jobs** (one per URL chunk)
4. **Processes URLs** and extracts demo data
5. **Saves results** as JSON files

Ready to process your data at scale! 🎉
EOF

echo "✅ Quick start guide created"

# Final summary
echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "📁 Project created in: $(pwd)"
echo "📄 Quick start guide: CLOUDSHELL_QUICKSTART.md"
echo ""
echo "🚀 Ready to deploy! Run:"
echo "  bash scripts/quick-deploy.sh"
echo ""
echo "📊 Monitor progress:"
echo "  bash scripts/monitor.sh"
echo ""
echo "📥 Collect results:"
echo "  bash scripts/collect-results.sh"
echo ""
echo "🎉 Ghost Protocol CloudShell setup complete!"