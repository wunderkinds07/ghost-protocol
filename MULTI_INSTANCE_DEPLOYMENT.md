# Multi-Instance Deployment Guide

## Step 1: Setup GitHub Repository

```bash
# After creating repo on GitHub, run:
./setup_github_repo.sh https://github.com/YOURUSERNAME/1stdibs-extractor.git
```

## Step 2: Deploy to Multiple Instances

### Option A: Deploy to Each Instance Individually
```bash
# Instance 1 (URLs 0-4999)
./deploy_via_git.sh https://github.com/YOURUSERNAME/1stdibs-extractor.git INSTANCE_1_IP

# Instance 2 (URLs 5000-9999)  
./deploy_via_git.sh https://github.com/YOURUSERNAME/1stdibs-extractor.git INSTANCE_2_IP

# Instance 3 (URLs 10000-14999)
./deploy_via_git.sh https://github.com/YOURUSERNAME/1stdibs-extractor.git INSTANCE_3_IP
```

### Option B: Batch Deploy Script
```bash
#!/bin/bash
# Save as deploy_all_instances.sh

REPO_URL="https://github.com/YOURUSERNAME/1stdibs-extractor.git"
INSTANCES=(
    "INSTANCE_1_IP"
    "INSTANCE_2_IP" 
    "INSTANCE_3_IP"
    "INSTANCE_4_IP"
    "INSTANCE_5_IP"
)

for i in "${!INSTANCES[@]}"; do
    INSTANCE_IP="${INSTANCES[$i]}"
    INSTANCE_NUM=$((i + 1))
    
    echo "🚀 Deploying to Instance $INSTANCE_NUM: $INSTANCE_IP"
    ./deploy_via_git.sh "$REPO_URL" "$INSTANCE_IP" &
    
    # Deploy in parallel (remove & to deploy sequentially)
done

wait  # Wait for all deployments to complete
echo "✅ All instances deployed!"
```

## Step 3: Configure Each Instance

After deployment, SSH into each instance and configure:

### Instance 1
```bash
ssh ubuntu@INSTANCE_1_IP
cd 1stdibs-extractor

# Run 5 containers processing URLs 0-4999
for i in {1..5}; do
    docker run -d \
        --name extractor-$i \
        -e CONTAINER_ID=$i \
        -e URL_CHUNK_START=$(( ($i - 1) * 1000 )) \
        -e URL_CHUNK_SIZE=1000 \
        -e NTFY_TOPIC=instance1-$i \
        -v $(pwd)/data/container$i:/app/data \
        1stdibs-extractor
done
```

### Instance 2  
```bash
ssh ubuntu@INSTANCE_2_IP
cd 1stdibs-extractor

# Run 5 containers processing URLs 5000-9999
for i in {1..5}; do
    docker run -d \
        --name extractor-$i \
        -e CONTAINER_ID=$i \
        -e URL_CHUNK_START=$(( 5000 + ($i - 1) * 1000 )) \
        -e URL_CHUNK_SIZE=1000 \
        -e NTFY_TOPIC=instance2-$i \
        -v $(pwd)/data/container$i:/app/data \
        1stdibs-extractor
done
```

### Instance 3
```bash
ssh ubuntu@INSTANCE_3_IP
cd 1stdibs-extractor

# Run 5 containers processing URLs 10000-14999
for i in {1..5}; do
    docker run -d \
        --name extractor-$i \
        -e CONTAINER_ID=$i \
        -e URL_CHUNK_START=$(( 10000 + ($i - 1) * 1000 )) \
        -e URL_CHUNK_SIZE=1000 \
        -e NTFY_TOPIC=instance3-$i \
        -v $(pwd)/data/container$i:/app/data \
        1stdibs-extractor
done
```

## Step 4: Monitor All Instances

### Create Monitoring Script
```bash
#!/bin/bash
# Save as monitor_all.sh

INSTANCES=(
    "INSTANCE_1_IP"
    "INSTANCE_2_IP"
    "INSTANCE_3_IP"
)

echo "📊 Multi-Instance Status Dashboard"
echo "================================="

for i in "${!INSTANCES[@]}"; do
    INSTANCE_IP="${INSTANCES[$i]}"
    INSTANCE_NUM=$((i + 1))
    
    echo ""
    echo "🖥️ Instance $INSTANCE_NUM ($INSTANCE_IP):"
    echo "--------------------------------"
    
    ssh ubuntu@$INSTANCE_IP "
        echo 'Containers running:'
        docker ps --filter name=extractor --format 'table {{.Names}}\t{{.Status}}'
        echo ''
        echo 'Extracted files:'
        find ~/1stdibs-extractor/data -name '*.json' 2>/dev/null | wc -l
    " 2>/dev/null || echo "❌ Cannot connect to instance"
done

echo ""
echo "🔄 Refresh: ./monitor_all.sh"
```

### Monitor with ntfy.sh
Subscribe to notifications:
- `instance1-1`, `instance1-2`, `instance1-3`, `instance1-4`, `instance1-5`
- `instance2-1`, `instance2-2`, `instance2-3`, `instance2-4`, `instance2-5`
- `instance3-1`, `instance3-2`, `instance3-3`, `instance3-4`, `instance3-5`

## Step 5: Collect Results

### Automated Collection Script
```bash
#!/bin/bash
# Save as collect_results.sh

INSTANCES=(
    "INSTANCE_1_IP"
    "INSTANCE_2_IP"
    "INSTANCE_3_IP"
)

mkdir -p results/

for i in "${!INSTANCES[@]}"; do
    INSTANCE_IP="${INSTANCES[$i]}"
    INSTANCE_NUM=$((i + 1))
    
    echo "📥 Collecting from Instance $INSTANCE_NUM..."
    
    scp -r ubuntu@$INSTANCE_IP:~/1stdibs-extractor/data/container*/extracted/*.json \
        results/instance${INSTANCE_NUM}/ 2>/dev/null || echo "No files yet on instance $INSTANCE_NUM"
done

echo "📊 Total extracted files: $(find results -name '*.json' | wc -l)"
```

## Scaling Recommendations

### Small Scale (Test)
- 3 instances × 2 containers = 6 total containers
- Process 100-500 URLs per container
- Monitor with basic scripts

### Medium Scale  
- 5 instances × 5 containers = 25 total containers
- Process 1,000-2,000 URLs per container
- Use ntfy.sh notifications
- Automated monitoring

### Large Scale (1M URLs)
- 10 instances × 10 containers = 100 total containers
- Process 5,000-10,000 URLs per container  
- S3 integration for results
- CloudWatch monitoring
- Auto-scaling groups

## Cost Optimization

### Lightsail Instances
- $20/month × 5 instances = $100/month
- Can process 25,000-50,000 URLs
- Good for sustained workloads

### EC2 Spot Instances
- ~$0.01/hour × 10 instances = $2.40/day
- Process 1M URLs in 1-2 days
- Good for batch processing

### Instance Selection
- **t3.medium** (2 vCPU, 4GB): 3-5 containers
- **t3.large** (2 vCPU, 8GB): 5-8 containers  
- **t3.xlarge** (4 vCPU, 16GB): 8-12 containers

## Troubleshooting

### Instance Connection Issues
```bash
# Test connectivity
ping INSTANCE_IP
ssh -v ubuntu@INSTANCE_IP

# Check security groups allow SSH (port 22)
```

### Container Issues
```bash
# SSH into instance
ssh ubuntu@INSTANCE_IP

# Check container status
docker ps -a --filter name=extractor

# Check logs
docker logs extractor-1

# Restart container
docker restart extractor-1
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Check system resources
top
df -h

# Reduce containers if overloaded
docker stop extractor-4 extractor-5
```