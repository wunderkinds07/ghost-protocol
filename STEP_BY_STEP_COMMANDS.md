# Step-by-Step Commands: Copy and Paste Guide

## 📋 Exact Commands for Complete Deployment

Just copy and paste these commands in order. Each section builds on the previous one.

## Phase 1: Initial Setup

### AWS Account & CLI Setup
```bash
# 1. Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# 2. Configure AWS (you'll need your Access Key ID and Secret Key)
aws configure
# Enter your credentials when prompted

# 3. Test connection
aws sts get-caller-identity
```

### Install Required Tools
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install utilities
sudo apt-get update && sudo apt-get install -y jq bc

# Restart shell or logout/login to apply docker group
newgrp docker
```

### Verify Installation
```bash
echo "=== Verification ==="
aws --version
docker --version
kubectl version --client
eksctl version
helm version
jq --version
echo "✅ All tools ready!"
```

## Phase 2: Prepare Data

```bash
# Create test URLs file (replace with your actual file)
cat > test-urls.txt << 'EOF'
https://www.1stdibs.com/furniture/seating/benches/mid-century-modern-wooden-bench-unknown-danish-cabinetmaker-1960s/id-f_31310552/
https://www.1stdibs.com/furniture/seating/chairs/mid-century-modern-stacking-chairs-verner-panton-herman-miller-1960s/id-f_1234567/
https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-modern-dining-table-carlo-scarpa-1970s/id-f_2345678/
EOF

# Split into chunks (replace test-urls.txt with your file)
python3 prepare_chunks.py test-urls.txt 5000 chunks

# Verify chunks were created
ls chunks/
echo "Chunks created: $(ls chunks/urls_chunk_*.txt | wc -l)"
```

## Phase 3: Single Region Deployment (Easiest)

```bash
# Go to AWS deployment directory
cd aws-k8s/

# Estimate costs first
./cost-estimator.sh 3 "us-east-1" t3.medium false

# Setup EKS cluster (takes 15-20 minutes)
echo "⏰ Creating EKS cluster - this takes 15-20 minutes..."
./setup-eks-cluster.sh ghost-protocol us-east-1

# Build and push Docker image
echo "🐳 Building Docker image..."
./build-and-push-image.sh us-east-1

# Deploy processing jobs
echo "🚀 Deploying jobs..."
./deploy-ghost-protocol.sh us-east-1

# Monitor progress
./monitor-jobs-us-east-1.sh
```

## Phase 4: Multi-Region Deployment (Recommended)

```bash
# Go to AWS deployment directory
cd aws-k8s/

# Estimate costs for multi-region
./cost-estimator.sh 15 "us-east-1,us-west-2,eu-west-1" t3.medium false

# Deploy everything across 3 regions
echo "🌍 Deploying across 3 regions - takes 25-30 minutes..."
./deploy-multi-region.sh "us-east-1,us-west-2,eu-west-1" 50

# Monitor all regions
./monitor-all-regions.sh
```

## Phase 5: Monitor Progress

### Check Overall Status
```bash
# Monitor all regions (run this periodically)
./monitor-all-regions.sh

# Check specific region
./monitor-jobs-us-east-1.sh

# View Kubernetes resources
kubectl get jobs -n ghost-protocol
kubectl get pods -n ghost-protocol
```

### View Logs
```bash
# Get pod name first
kubectl get pods -n ghost-protocol

# View logs (replace POD_NAME with actual pod name)
kubectl logs -n ghost-protocol POD_NAME

# Follow logs in real-time
kubectl logs -f -n ghost-protocol POD_NAME
```

### Check AWS Costs
```bash
# View current AWS spending
aws ce get-cost-and-usage \
  --time-period Start=2024-12-01,End=2024-12-31 \
  --granularity DAILY \
  --metrics BlendedCost
```

## Phase 6: Collect Results

### Wait for Completion
```bash
# Check if all jobs are complete
./monitor-all-regions.sh

# Look for "Completed: X (100%)" in the output
```

### Collect All Data
```bash
# Collect results from all regions
./collect-all-results.sh

# Check what was collected
ls multi-region-results-*/

# Merge all data into single file
cd ..
python3 merge_extracted_data.py aws-k8s/multi-region-results-*/

# Check final results
ls -la merged_products.json
echo "Total products extracted: $(cat merged_products.json | jq '.total_products')"
```

## Phase 7: Cleanup (Important!)

### Delete Everything
```bash
cd aws-k8s/

# Emergency cleanup - deletes ALL resources
./cleanup-all-resources.sh

# Or manual cleanup per region
for region in us-east-1 us-west-2 eu-west-1; do
    eksctl delete cluster --name ghost-protocol --region $region
done

# Clean up ECR repositories
for region in us-east-1 us-west-2 eu-west-1; do
    aws ecr delete-repository --repository-name ghost-protocol --region $region --force
done

echo "✅ Cleanup complete!"
```

## Quick Commands Reference

### Start Processing
```bash
# Single region
cd aws-k8s && ./setup-eks-cluster.sh ghost-protocol us-east-1 && ./build-and-push-image.sh us-east-1 && ./deploy-ghost-protocol.sh us-east-1

# Multi-region
cd aws-k8s && ./deploy-multi-region.sh "us-east-1,us-west-2,eu-west-1" 50
```

### Check Status
```bash
# All regions
./monitor-all-regions.sh

# Single region
kubectl get jobs -n ghost-protocol
```

### Get Results
```bash
# Collect and merge
./collect-all-results.sh && cd .. && python3 merge_extracted_data.py aws-k8s/multi-region-results-*/
```

### Emergency Stop
```bash
# Stop all processing and delete everything
cd aws-k8s && ./cleanup-all-resources.sh
```

## Troubleshooting Commands

### AWS Issues
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check AWS regions
aws ec2 describe-regions --output table

# Check service limits
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
```

### Kubernetes Issues
```bash
# Check cluster status
kubectl get nodes

# Check failed jobs
kubectl get jobs -n ghost-protocol --field-selector status.successful!=1

# Describe failed pod
kubectl describe pod POD_NAME -n ghost-protocol

# Check events
kubectl get events -n ghost-protocol --sort-by='.lastTimestamp'
```

### Docker Issues
```bash
# Test Docker
docker run hello-world

# Check if you're in docker group
groups | grep docker

# Fix permissions
sudo usermod -aG docker $USER && newgrp docker
```

## Example Full Workflow

```bash
# Complete workflow in one go
# (Replace test-urls.txt with your actual file)

# 1. Setup
aws configure  # Enter your credentials
python3 prepare_chunks.py test-urls.txt 5000 chunks

# 2. Deploy
cd aws-k8s
./deploy-multi-region.sh "us-east-1,us-west-2" 20

# 3. Monitor (wait for completion)
while true; do 
    ./monitor-all-regions.sh
    sleep 60
done

# 4. Collect results
./collect-all-results.sh
cd .. && python3 merge_extracted_data.py aws-k8s/multi-region-results-*/

# 5. Cleanup
cd aws-k8s && ./cleanup-all-resources.sh
```

That's it! Just copy these commands step by step and you'll have a fully working multi-region deployment. 🚀