# Complete Setup Guide: From Zero to Deployed

## 🎯 Everything You Need to Know - Step by Step

This guide assumes you're starting from scratch with no AWS or Kubernetes experience.

## Phase 1: AWS Account Setup (10 minutes)

### Step 1: Create AWS Account
1. Go to [aws.amazon.com](https://aws.amazon.com)
2. Click "Create an AWS Account"
3. Follow the signup process (you'll need a credit card)
4. **Important**: Enable MFA (Multi-Factor Authentication) for security

### Step 2: Create IAM User (Recommended for Security)
1. Login to AWS Console
2. Go to **IAM** service
3. Click **Users** → **Add User**
4. Username: `ghost-protocol-user`
5. Access type: ✅ **Programmatic access**
6. Permissions: **Attach existing policies directly**
7. Search and select: `AdministratorAccess` (for simplicity)
8. **Save the Access Key ID and Secret Access Key** - you'll need these!

### Step 3: Install AWS CLI
```bash
# Download and install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
# Should show: aws-cli/2.x.x
```

### Step 4: Configure AWS CLI
```bash
aws configure

# Enter when prompted:
# AWS Access Key ID: [Your Access Key from Step 2]
# AWS Secret Access Key: [Your Secret Key from Step 2]  
# Default region name: us-east-1
# Default output format: json
```

### Step 5: Test AWS Connection
```bash
# Test your AWS connection
aws sts get-caller-identity

# Should return something like:
# {
#     "UserId": "AIDACKCEVSQ6C2EXAMPLE",
#     "Account": "123456789012", 
#     "Arn": "arn:aws:iam::123456789012:user/ghost-protocol-user"
# }
```

## Phase 2: Install Required Tools (5 minutes)

### Step 1: Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group (to run without sudo)
sudo usermod -aG docker $USER

# Log out and back in, then test
docker --version
docker run hello-world
```

### Step 2: Install Kubernetes Tools
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Install jq (for JSON processing)
sudo apt-get update && sudo apt-get install -y jq bc
```

### Step 3: Verify Everything Works
```bash
echo "=== Verification ==="
aws --version
docker --version  
kubectl version --client
eksctl version
helm version
jq --version
echo "✅ All tools installed!"
```

## Phase 3: Prepare Your Data (5 minutes)

### Step 1: Get Your URLs Ready
```bash
# If you have a file with URLs (one per line)
head -5 your-urls-file.txt
# Should show URLs like:
# https://www.1stdibs.com/furniture/seating/chairs/...
# https://www.1stdibs.com/furniture/tables/...

# Split into chunks for processing
python3 prepare_chunks.py your-urls-file.txt 5000 chunks

# Check what was created
ls chunks/
# You should see: chunks_manifest.json, urls_chunk_0001.txt, urls_chunk_0002.txt, etc.

echo "Total chunks created: $(ls chunks/urls_chunk_*.txt | wc -l)"
```

### Step 2: Test Processing Locally (Optional but Recommended)
```bash
# Test with a small chunk to make sure everything works
python3 test_local.py

# Should process a few URLs and show results like:
# ✓ Extracted: 19th Century French Louis XIV Walnut Marble Top Nightstand
# Success rate: 80.0%
```

## Phase 4: Deploy to AWS (20-30 minutes)

### Option A: Single Region Deployment (Easier)

```bash
cd aws-k8s/

# Step 1: Estimate costs first
./cost-estimator.sh 10000 "us-east-1" t3.medium false

# Step 2: Setup EKS cluster (takes 15-20 minutes)
echo "⏰ Setting up EKS cluster - this takes 15-20 minutes, grab a coffee!"
./setup-eks-cluster.sh ghost-protocol us-east-1

# Step 3: Build and push Docker image (takes 5 minutes)
echo "🐳 Building Docker image..."
./build-and-push-image.sh us-east-1

# Step 4: Deploy processing jobs
echo "🚀 Deploying processing jobs..."
./deploy-ghost-protocol.sh us-east-1
```

### Option B: Multi-Region Deployment (Recommended for Large Datasets)

```bash
cd aws-k8s/

# Step 1: Estimate costs for multi-region
./cost-estimator.sh 100000 "us-east-1,us-west-2,eu-west-1" t3.medium true

# Step 2: Deploy everything automatically
echo "🌍 Deploying across multiple regions - this takes 20-30 minutes"
./deploy-multi-region.sh "us-east-1,us-west-2,eu-west-1" 50
```

### What Happens During Deployment:
```
[15:30] Creating EKS cluster in us-east-1...
[15:32] Creating EKS cluster in us-west-2...
[15:34] Creating EKS cluster in eu-west-1...
[15:45] Building Docker images...
[15:50] Distributing chunks across regions...
[15:55] Deploying Kubernetes jobs...
[16:00] ✅ Deployment complete! Jobs are running...
```

## Phase 5: Monitor Progress (Ongoing)

### Watch All Regions
```bash
# Monitor progress across all regions
./monitor-all-regions.sh

# Example output:
# === Ghost Protocol Multi-Region Status ===
# Region: us-east-1
#   Jobs: 67, Completed: 12, Running: 45, Failed: 0
# Region: us-west-2  
#   Jobs: 66, Completed: 8, Running: 48, Failed: 0
# Region: eu-west-1
#   Jobs: 67, Completed: 15, Running: 42, Failed: 0
# 
# === Global Summary ===
# Total Jobs: 200
# Completed: 35 (17.5%)
# Running: 135
# Failed: 0
```

### Monitor Individual Regions
```bash
# Check specific region
./monitor-jobs-us-east-1.sh

# View detailed job status
kubectl get jobs -n ghost-protocol

# Check pod logs
kubectl logs -n ghost-protocol <pod-name>
```

### Check AWS Costs in Real-Time
1. Go to AWS Console → **Billing & Cost Management**
2. Click **Cost Explorer**
3. View current spending

## Phase 6: Collect Results (When Complete)

### Wait for Completion
```bash
# Jobs are complete when monitor shows 100% completion
./monitor-all-regions.sh

# Look for: "Completed: 200 (100%)"
```

### Collect All Data
```bash
# Collect results from all regions
./collect-all-results.sh

# This creates a directory like: multi-region-results-20241209_143022/
# With subdirectories for each region containing extracted data

# Merge everything into a single dataset
python3 ../merge_extracted_data.py multi-region-results-*/

# Final result: merged_products.json with all your data!
```

## Phase 7: Cleanup (Important!)

### Stop All Processing
```bash
# Delete all clusters to stop charges
for region in us-east-1 us-west-2 eu-west-1; do
    echo "Deleting cluster in $region..."
    eksctl delete cluster --name ghost-protocol --region $region
done

# Clean up ECR repositories
for region in us-east-1 us-west-2 eu-west-1; do
    aws ecr delete-repository --repository-name ghost-protocol --region $region --force 2>/dev/null || true
done

echo "✅ All resources cleaned up!"
```

## Troubleshooting Common Issues

### 1. AWS CLI Not Working
```bash
# Check configuration
aws configure list

# Test connection
aws sts get-caller-identity

# If it fails, reconfigure:
aws configure
```

### 2. Docker Permission Denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker
```

### 3. EKS Cluster Creation Fails
```bash
# Check AWS limits
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A

# Try different region or instance type
./setup-eks-cluster.sh ghost-protocol us-west-1 t3.small
```

### 4. Jobs Failing
```bash
# Check job status
kubectl get jobs -n ghost-protocol

# View failed pod logs
kubectl logs <failed-pod-name> -n ghost-protocol

# Describe job for more details
kubectl describe job <job-name> -n ghost-protocol
```

### 5. High AWS Costs
```bash
# Check current spending
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-12-31 --granularity MONTHLY --metrics BlendedCost

# Delete everything immediately
./cleanup-all-resources.sh
```

## Security Best Practices

1. **Use IAM users** (not root account)
2. **Enable MFA** on your AWS account
3. **Delete clusters** when not in use
4. **Monitor costs** regularly
5. **Use least privilege** permissions (not AdministratorAccess in production)

## Cost Control Tips

1. **Start small**: Test with 1000 URLs first
2. **Use spot instances**: Add `--spot` flag for 70% savings
3. **Set billing alerts**: Get notified if costs exceed $50
4. **Delete immediately**: Don't leave clusters running
5. **Monitor progress**: Check `./monitor-all-regions.sh` regularly

## Ready to Process Millions of URLs! 🚀

You now have everything needed to:
- ✅ Deploy across multiple AWS regions
- ✅ Process millions of URLs in parallel  
- ✅ Monitor progress in real-time
- ✅ Collect and merge all results
- ✅ Control costs effectively

The system is production-ready and can scale to handle any dataset size!