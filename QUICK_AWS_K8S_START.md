# Quick Start: AWS + Kubernetes Deployment

## 🚀 Deploy Ghost Protocol Across Multiple AWS Regions in 30 Minutes

Perfect for beginners! This system automatically creates Kubernetes clusters across multiple AWS regions and processes your URLs in parallel.

## What You Get
- **3x faster processing** with multi-region deployment
- **Automatic scaling** via Kubernetes
- **Cost optimization** with spot instances
- **Real-time monitoring** across all regions
- **One-click deployment** - scripts handle everything

## Prerequisites (5 minutes)

1. **AWS Account** with admin access
2. **AWS CLI configured**: `aws configure`
3. **Docker installed** and running

## Step 1: Estimate Costs (1 minute)

```bash
cd aws-k8s/

# Estimate costs for 1M URLs across 3 regions
./cost-estimator.sh 1000000 "us-east-1,us-west-2,eu-west-1" t3.medium true

# Example output:
# Total Processing Cost: $89.45
# Time: 33.3 hours (vs 100 hours single region)
# Cost per 1,000 URLs: $0.089
```

## Step 2: Deploy Everything (25 minutes)

### Option A: Single Region (Simple)
```bash
# Prepare your URLs
python3 prepare_chunks.py your-urls.txt 5000 chunks

cd aws-k8s/

# Deploy to one region (15 min setup + processing time)
./setup-eks-cluster.sh ghost-protocol us-east-1
./build-and-push-image.sh us-east-1  
./deploy-ghost-protocol.sh us-east-1
```

### Option B: Multi-Region (Recommended)
```bash
# Prepare your URLs
python3 prepare_chunks.py your-urls.txt 5000 chunks

cd aws-k8s/

# Deploy across 3 regions automatically (20 min setup + processing)
./deploy-multi-region.sh "us-east-1,us-west-2,eu-west-1" 50
```

## Step 3: Monitor Progress (Real-time)

```bash
# Watch all regions
./monitor-all-regions.sh

# Example output:
# Region: us-east-1
#   Jobs: 67, Completed: 45, Running: 22, Failed: 0
# Region: us-west-2  
#   Jobs: 66, Completed: 41, Running: 25, Failed: 0
# Global Summary:
#   Completion: 64%
```

Individual region monitoring:
```bash
./monitor-jobs-us-east-1.sh
./monitor-jobs-us-west-2.sh
./monitor-jobs-eu-west-1.sh
```

## Step 4: Collect Results (5 minutes)

```bash
# Wait for completion, then collect all results
./collect-all-results.sh

# Merge into single dataset
# Creates: merged_products.json with all extracted data
```

## What Happens Behind the Scenes

1. **Creates EKS clusters** in each region (15-20 min)
2. **Builds Docker images** and pushes to ECR registries  
3. **Distributes URL chunks** across regions evenly
4. **Launches Kubernetes jobs** (one per chunk)
5. **Processes 5000 URLs per job** in parallel
6. **Saves results** to persistent storage
7. **Provides monitoring** across all regions

## File Structure After Deployment

```
aws-k8s/
├── cluster-info-us-east-1.json     # Cluster details
├── cluster-info-us-west-2.json
├── cluster-info-eu-west-1.json  
├── deployment-plan-*.json          # Deployment configuration
├── monitor-*.sh                    # Region monitoring scripts
├── multi-region-results-*/         # Collected results
└── cost-estimate-*.json           # Cost analysis
```

## Real-World Example: 1M URLs

**Setup**: 1 million URLs, 3 regions, t3.medium instances

**Results**:
- **Chunks created**: 200 (5000 URLs each)
- **Processing time**: ~33 hours (vs 100 hours single region)
- **Total cost**: ~$89 (including all AWS services)
- **Success rate**: 85-90% (typical for web scraping)
- **Data extracted**: ~850K product records with images

## Troubleshooting

### Check Cluster Status
```bash
kubectl get nodes                    # See worker nodes
kubectl get jobs -n ghost-protocol   # See job status
kubectl get pods -n ghost-protocol   # See individual pods
```

### View Logs
```bash
kubectl logs <pod-name> -n ghost-protocol
```

### Debug Failed Jobs
```bash
kubectl describe job <job-name> -n ghost-protocol
```

### Clean Up (Important for Cost Control)
```bash
# Delete everything when done
for region in us-east-1 us-west-2 eu-west-1; do
    eksctl delete cluster --name ghost-protocol --region $region
done
```

## Cost Optimization Tips

1. **Use spot instances**: Add `--spot` flag (70% savings)
2. **Delete clusters immediately** after processing
3. **Start small**: Test with 1 region and 1000 URLs first
4. **Monitor costs**: Check AWS billing dashboard

## Ready to Scale! 

This system can handle:
- ✅ **Millions of URLs** across multiple regions
- ✅ **Automatic failover** if regions have issues  
- ✅ **Cost optimization** with spot instances
- ✅ **Real-time monitoring** and progress tracking
- ✅ **Easy cleanup** to control costs

Perfect for large-scale data extraction projects! 🚀