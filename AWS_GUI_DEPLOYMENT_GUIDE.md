# AWS GUI Deployment Guide for Ghost Protocol

## 🖥️ Deploy Ghost Protocol Using AWS Console (No Command Line!)

This guide shows you how to deploy Ghost Protocol using only AWS web interfaces - perfect if you prefer clicking buttons over typing commands.

## Overview of GUI Options

AWS offers several GUI approaches:

1. **AWS Console + EKS** (Recommended) - Full web interface
2. **AWS Cloud9** - Web-based IDE with built-in terminal
3. **AWS CloudShell** - Browser-based command line
4. **AWS CodeCommit + CodeBuild** - Fully managed CI/CD

## Option 1: AWS Console + EKS (Recommended)

### Phase 1: Setup EKS Cluster via Console (20 minutes)

#### Step 1: Create EKS Cluster
1. **Login to AWS Console**: [console.aws.amazon.com](https://console.aws.amazon.com)
2. **Go to EKS Service**: Search "EKS" in the services menu
3. **Click "Create cluster"**
4. **Cluster Configuration**:
   - Name: `ghost-protocol`
   - Version: `1.27` (latest)
   - Cluster service role: Create new role or use existing
5. **Networking**:
   - VPC: Use default VPC
   - Subnets: Select all available
   - Security groups: Default
   - Cluster endpoint access: Public and private
6. **Logging**: Enable all log types (optional)
7. **Click "Create"** (takes 15-20 minutes)

#### Step 2: Create Node Group
1. **Go to your cluster** → **Compute** tab
2. **Click "Add node group"**
3. **Node group configuration**:
   - Name: `ghost-protocol-nodes`
   - Node IAM role: Create new or use existing
4. **Compute and scaling configuration**:
   - AMI type: `Amazon Linux 2 (AL2_x86_64)`
   - Capacity type: `On-Demand` (or `Spot` for savings)
   - Instance types: `t3.medium`
   - Disk size: `20 GB`
5. **Scaling configuration**:
   - Desired size: `3`
   - Minimum size: `1`
   - Maximum size: `10`
6. **Networking**:
   - Subnets: Select private subnets
   - SSH key pair: Create or select existing
7. **Click "Create"** (takes 5-10 minutes)

### Phase 2: Setup Container Registry (5 minutes)

#### Step 1: Create ECR Repository
1. **Go to ECR Service** in AWS Console
2. **Click "Create repository"**
3. **Repository configuration**:
   - Visibility: `Private`
   - Repository name: `ghost-protocol`
   - Tag immutability: `Mutable`
4. **Click "Create repository"**

### Phase 3: Build and Push Image via Cloud9 (15 minutes)

#### Step 1: Launch Cloud9 Environment
1. **Go to Cloud9 Service** in AWS Console
2. **Click "Create environment"**
3. **Environment settings**:
   - Name: `ghost-protocol-dev`
   - Instance type: `t3.small`
   - Platform: `Amazon Linux 2`
4. **Click "Create"** (takes 2-3 minutes)

#### Step 2: Setup Ghost Protocol in Cloud9
1. **Open your Cloud9 environment**
2. **In the terminal, run these commands**:

```bash
# Clone or upload your Ghost Protocol code
# For this example, we'll recreate the essential files

# Create project structure
mkdir ghost-protocol && cd ghost-protocol

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y wget curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY docker/entrypoint.py .
COPY docker/notifier.py .
COPY docker/s3_uploader.py .

# Create data directories
RUN mkdir -p /app/data/output /app/data/logs

ENV PYTHONUNBUFFERED=1
CMD ["python", "entrypoint.py"]
EOF

# Create requirements.txt
cat > requirements.txt << 'EOF'
requests==2.32.3
beautifulsoup4==4.13.4
lxml==5.4.0
tqdm>=4.65.0
pandas==2.2.3
numpy==1.26.4
EOF
```

3. **Upload your Ghost Protocol source files**:
   - Use Cloud9's file upload feature to upload your `src/` directory
   - Upload `docker/entrypoint.py`, `docker/notifier.py`, `docker/s3_uploader.py`

#### Step 3: Build and Push Image
```bash
# Get ECR login
REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ghost-protocol"

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Build image
docker build -t ghost-protocol:latest .

# Tag and push
docker tag ghost-protocol:latest $ECR_URI:latest
docker push $ECR_URI:latest

echo "Image pushed to: $ECR_URI:latest"
```

### Phase 4: Deploy via Kubernetes Dashboard (20 minutes)

#### Step 1: Install Kubernetes Dashboard
1. **In Cloud9 terminal**:
```bash
# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name ghost-protocol

# Install Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user
cat > dashboard-adminuser.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

kubectl apply -f dashboard-adminuser.yaml

# Get access token
kubectl -n kubernetes-dashboard create token admin-user
```

2. **Start proxy in Cloud9**:
```bash
kubectl proxy --port=8080 --address=0.0.0.0 --disable-filter=true
```

3. **Access Dashboard**:
   - In Cloud9, go to **Preview** → **Preview Running Application**
   - Navigate to: `/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`
   - Use the token from step 1 to login

#### Step 2: Create Namespace via Dashboard
1. **In Kubernetes Dashboard**:
   - Click **Namespaces** in left menu
   - Click **Create** button
   - Name: `ghost-protocol`
   - Click **Deploy**

#### Step 3: Create ConfigMap for URLs
1. **Create URL chunk files** in Cloud9:
```bash
# Create sample URLs (replace with your actual URLs)
mkdir chunks
cat > chunks/urls_chunk_0001.txt << 'EOF'
https://www.1stdibs.com/furniture/seating/benches/mid-century-modern-wooden-bench-unknown-danish-cabinetmaker-1960s/id-f_31310552/
https://www.1stdibs.com/furniture/seating/chairs/mid-century-modern-stacking-chairs-verner-panton-herman-miller-1960s/id-f_1234567/
https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-modern-dining-table-carlo-scarpa-1970s/id-f_2345678/
EOF
```

2. **In Dashboard**:
   - Go to **Config Maps** → **Create**
   - **From File**: Upload `chunks/urls_chunk_0001.txt`
   - Name: `ghost-protocol-urls-1`
   - Namespace: `ghost-protocol`
   - Click **Deploy**

#### Step 4: Create Job via Dashboard
1. **In Dashboard**:
   - Go to **Jobs** → **Create**
   - Click **Create from YAML**
   - Paste this YAML:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ghost-protocol-chunk-1
  namespace: ghost-protocol
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: ghost-protocol-processor
        image: YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com/ghost-protocol:latest
        env:
        - name: CHUNK_ID
          value: "1"
        - name: URLS_FILE
          value: "/app/data/urls_chunk.txt"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: data-volume
          mountPath: /app/data
        - name: urls-volume
          mountPath: /app/data/urls_chunk.txt
          subPath: urls_chunk_0001.txt
      volumes:
      - name: data-volume
        emptyDir: {}
      - name: urls-volume
        configMap:
          name: ghost-protocol-urls-1
```

2. **Replace placeholders**:
   - `YOUR_ACCOUNT_ID`: Your AWS account ID
   - `YOUR_REGION`: Your AWS region
3. **Click Deploy**

### Phase 5: Monitor via Dashboard

#### View Job Progress
1. **Go to Jobs** in dashboard
2. **Click on your job** to see details
3. **Check Pods** tab to see running containers
4. **View Logs** by clicking on pod name

#### View Pod Logs
1. **Go to Pods** in dashboard
2. **Click on your pod**
3. **Click Logs tab** to see real-time output

## Option 2: AWS Cloud9 IDE (Simplest)

### Complete Deployment in Cloud9

1. **Create Cloud9 Environment**:
   - Go to Cloud9 in AWS Console
   - Create new environment with `t3.medium` instance

2. **Run Complete Deployment**:
```bash
# In Cloud9 terminal, run our existing scripts
git clone <your-ghost-protocol-repo>
cd ghost-protocol

# Install eksctl in Cloud9
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Run our automated scripts
cd aws-k8s
./setup-eks-cluster.sh ghost-protocol us-east-1
./build-and-push-image.sh us-east-1
./deploy-ghost-protocol.sh us-east-1

# Monitor progress
./monitor-jobs-us-east-1.sh
```

## Option 3: AWS CodeCommit + CodeBuild (Fully Managed)

### Setup CI/CD Pipeline

#### Step 1: Create CodeCommit Repository
1. **Go to CodeCommit** in AWS Console
2. **Create repository**: `ghost-protocol`
3. **Upload your code** using the web interface

#### Step 2: Create CodeBuild Project
1. **Go to CodeBuild** in AWS Console
2. **Create build project**:
   - Name: `ghost-protocol-build`
   - Source: CodeCommit repository
   - Environment: `Managed image`, `Amazon Linux 2`, `Standard runtime`
   - Service role: Create new or use existing
3. **Create buildspec.yml**:

```yaml
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t ghost-protocol .
      - docker tag ghost-protocol:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/ghost-protocol:latest
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/ghost-protocol:latest
```

## Option 4: AWS App Runner (Simplest for Web Apps)

### Deploy via App Runner Console
1. **Go to App Runner** in AWS Console
2. **Create service**
3. **Source**: Container registry
4. **Select your ECR repository**
5. **Configure service** with appropriate resources
6. **Deploy**

## GUI Deployment Comparison

| Method | Difficulty | Time | Best For |
|--------|------------|------|----------|
| **EKS Console + Dashboard** | Medium | 60 min | Full control, learning K8s |
| **Cloud9 IDE** | Easy | 30 min | Familiar with terminals |
| **CodeCommit + CodeBuild** | Easy | 45 min | CI/CD workflows |
| **App Runner** | Very Easy | 15 min | Simple web applications |

## Monitoring via AWS Console

### CloudWatch Dashboards
1. **Go to CloudWatch** → **Dashboards**
2. **Create dashboard** for Ghost Protocol
3. **Add widgets** for:
   - EKS cluster metrics
   - Container CPU/Memory usage
   - Job completion rates

### EKS Console Monitoring
1. **Go to EKS** → **Your cluster**
2. **Workloads tab** shows all running jobs
3. **Resources tab** shows nodes and utilization

## Cost Management via Console

### Cost Explorer
1. **Go to Billing** → **Cost Explorer**
2. **Create cost report** filtered by:
   - Service: EKS, EC2, ECR
   - Tags: ghost-protocol

### Budgets
1. **Go to Billing** → **Budgets**
2. **Create budget** with alerts for Ghost Protocol spending

## Cleanup via Console

### Delete EKS Resources
1. **EKS Console** → **Workloads** → Delete all jobs
2. **EKS Console** → **Compute** → Delete node groups
3. **EKS Console** → **Clusters** → Delete cluster

### Delete Supporting Resources
1. **ECR Console** → Delete repositories
2. **Cloud9 Console** → Delete environments
3. **EC2 Console** → Terminate any remaining instances

## Summary

The **EKS Console + Kubernetes Dashboard** approach gives you the most control and learning opportunity, while **Cloud9** provides the perfect balance of GUI and command-line access. Choose based on your comfort level and requirements!

All these methods achieve the same result - deploying Ghost Protocol to process your URLs at scale. The GUI approaches are perfect for users who prefer visual interfaces over command lines. 🖥️✨