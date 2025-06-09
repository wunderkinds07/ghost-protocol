# Ghost Protocol: AWS + Kubernetes Deployment Guide

## 🚀 Complete Beginner's Guide to Multi-Region Deployment

This guide will help you deploy Ghost Protocol across multiple AWS regions using Kubernetes (EKS). No prior Kubernetes experience needed!

## What You'll Get

- **Automatic scaling**: Kubernetes manages your containers
- **Multi-region**: Deploy across US, Europe, Asia simultaneously  
- **Fault tolerance**: Failed jobs restart automatically
- **Cost optimization**: Use spot instances, auto-scaling
- **Easy monitoring**: Simple commands to check progress
- **One-click deployment**: Scripts handle everything

## Prerequisites

### 1. AWS Account Setup
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter your: Access Key ID, Secret Access Key, Default region (us-east-1), Output format (json)
```

### 2. Install Required Tools
The scripts will auto-install these, but you can install manually:
```bash
# Install eksctl (Kubernetes cluster manager)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Install kubectl (Kubernetes command tool)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm (Kubernetes package manager)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install jq (JSON processor)
sudo apt-get install jq
```

## Quick Start (Single Region)

### Step 1: Prepare Your Data
```bash
# Split your URLs into chunks
python3 prepare_chunks.py 1m-urls-1stdibs-raw.txt 5000 chunks

# This creates chunks/ directory with numbered files
ls chunks/  # You'll see urls_chunk_0001.txt, urls_chunk_0002.txt, etc.
```

### Step 2: Deploy to One Region
```bash
cd aws-k8s/

# Setup EKS cluster (takes 15-20 minutes)
./setup-eks-cluster.sh ghost-protocol us-east-1

# Build and push Docker image
./build-and-push-image.sh us-east-1

# Deploy Ghost Protocol jobs
./deploy-ghost-protocol.sh us-east-1
```

### Step 3: Monitor Progress
```bash
# Check overall status
./monitor-jobs-us-east-1.sh

# Check individual pods
kubectl get pods -n ghost-protocol

# View logs from a specific pod
kubectl logs -n ghost-protocol <pod-name>
```

### Step 4: Collect Results
```bash
# Wait for jobs to complete, then collect results
./collect-results-k8s.sh us-east-1

# Merge all data
python3 ../merge_extracted_data.py results-k8s-*/
```

## Multi-Region Deployment (Recommended)

Deploy across multiple regions for faster processing and better reliability:

```bash
cd aws-k8s/

# Deploy to 3 regions automatically
./deploy-multi-region.sh "us-east-1,us-west-2,eu-west-1" 50

# Monitor all regions
./monitor-all-regions.sh

# Collect results from all regions
./collect-all-results.sh
```

### What This Does:
1. **Creates EKS clusters** in each region
2. **Distributes chunks** evenly across regions  
3. **Builds Docker images** in each region's ECR
4. **Deploys processing jobs** in parallel
5. **Provides monitoring** across all regions

## Understanding the Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   US-East-1     │    │   US-West-2     │    │   EU-West-1     │
│                 │    │                 │    │                 │
│  EKS Cluster    │    │  EKS Cluster    │    │  EKS Cluster    │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │ Pod 1-50  │  │    │  │ Pod 51-100│  │    │  │ Pod 101-150│ │
│  │ (Chunks)  │  │    │  │ (Chunks)  │  │    │  │ (Chunks)   │ │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│                 │    │                 │    │                 │
│  ECR Registry   │    │  ECR Registry   │    │  ECR Registry   │
│  S3 Results     │    │  S3 Results     │    │  S3 Results     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Cost Estimation

### Single Region (us-east-1)
- **EKS cluster**: $0.10/hour (~$73/month)
- **Worker nodes** (t3.medium): $0.0416/hour per node
- **For 100 chunks**: ~20 nodes for 4 hours = $3.33
- **ECR storage**: $0.10/GB/month
- **Total for 500K URLs**: ~$80-100

### Multi-Region (3 regions)
- **3 EKS clusters**: ~$220/month  
- **Worker nodes**: Distributed across regions
- **For 1M URLs**: ~$200-300 total
- **Faster completion**: 2-3x faster than single region

### Cost Optimization Tips
```bash
# Use spot instances (50-90% cheaper)
./setup-eks-cluster.sh ghost-protocol us-east-1 t3.medium 1 20 --spot

# Delete clusters when done
eksctl delete cluster --name ghost-protocol --region us-east-1

# Use smaller instance types for testing
./setup-eks-cluster.sh ghost-protocol us-east-1 t3.small 1 10
```

## Monitoring and Troubleshooting

### Check Cluster Status
```bash
# List all clusters
eksctl get clusters

# Check node status
kubectl get nodes

# Check resource usage
kubectl top nodes
kubectl top pods -n ghost-protocol
```

### View Job Progress
```bash
# See all jobs
kubectl get jobs -n ghost-protocol

# Check failed jobs
kubectl get jobs -n ghost-protocol --field-selector status.successful!=1

# View job details
kubectl describe job <job-name> -n ghost-protocol
```

### Debug Issues
```bash
# View pod logs
kubectl logs -f <pod-name> -n ghost-protocol

# Get pod details
kubectl describe pod <pod-name> -n ghost-protocol

# Check events
kubectl get events -n ghost-protocol --sort-by='.lastTimestamp'
```

## Advanced Configuration

### Custom Resource Limits
Edit `k8s/job.yaml`:
```yaml
resources:
  requests:
    memory: "2Gi"      # Increase for larger datasets
    cpu: "1000m"       # Increase for faster processing
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### Enable S3 Upload
Edit `k8s/configmap.yaml`:
```yaml
data:
  S3_BUCKET: "your-results-bucket"
  S3_PREFIX: "ghost-protocol-results"
```

### Slack Notifications
```yaml
data:
  SLACK_WEBHOOK: "https://hooks.slack.com/your-webhook"
```

## Cleanup

### Delete Everything
```bash
# Delete all clusters
for region in us-east-1 us-west-2 eu-west-1; do
    eksctl delete cluster --name ghost-protocol --region $region
done

# Delete ECR repositories
for region in us-east-1 us-west-2 eu-west-1; do
    aws ecr delete-repository --repository-name ghost-protocol --region $region --force
done
```

### Partial Cleanup
```bash
# Delete just the jobs (keep cluster)
kubectl delete jobs --all -n ghost-protocol

# Delete namespace (removes all Ghost Protocol resources)
kubectl delete namespace ghost-protocol
```

## FAQ

**Q: How long does deployment take?**
A: EKS cluster setup: 15-20 minutes. Processing 5000 URLs: 2-4 hours.

**Q: Can I pause and resume?**
A: Yes! Kubernetes jobs can be paused. Completed work is saved.

**Q: What if my laptop disconnects?**
A: Everything runs in the cloud. You can reconnect anytime and check progress.

**Q: How do I scale up/down?**
A: Adjust the max nodes in setup script or use `kubectl scale`.

**Q: Can I use different regions?**
A: Yes! Modify the regions list in deploy-multi-region.sh.

**Q: What about data privacy?**
A: Data stays in your AWS account. Choose regions based on compliance needs.

## Support

- Check the logs: `kubectl logs <pod-name> -n ghost-protocol`
- Monitor resources: `./monitor-all-regions.sh`
- AWS documentation: https://docs.aws.amazon.com/eks/
- Kubernetes docs: https://kubernetes.io/docs/

## Ready to Deploy! 🚀

You now have a production-ready, multi-region Ghost Protocol deployment system that can scale to process millions of URLs efficiently and cost-effectively!