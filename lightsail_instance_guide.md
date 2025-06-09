# Use Lightsail Instance (Not Container Service)

## Step 1: Create Lightsail Instance Instead
Don't use Container Service. Instead:
1. Go to Lightsail home
2. Click "Create instance" (not container)
3. Choose:
   - Singapore region (same as your screenshot)
   - Ubuntu 20.04 OS
   - $40 plan (4 GB RAM, 2 vCPUs)

## Step 2: Quick Setup Script
Once instance is created, SSH in and run:

```bash
#!/bin/bash
# Save as setup.sh

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create project directory
mkdir -p ~/1stdibs-extraction
cd ~/1stdibs-extraction

# Create simple test Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
RUN pip install requests beautifulsoup4 lxml
COPY . .
CMD ["python", "-c", "print('Container working!')"]
EOF

# Build test image
docker build -t extractor .

echo "✅ Setup complete! Docker is ready."
```

## Step 3: Run Multiple Containers on Single Instance

```bash
# Run 10 containers in parallel on one $40 instance
for i in {1..10}; do
  docker run -d \
    --name extractor-$i \
    --memory="350m" \
    --cpus="0.15" \
    -e CONTAINER_ID=$i \
    -e START=$((($i-1)*1000)) \
    -e SIZE=1000 \
    extractor
done
```

## Cost Comparison

| Approach | Monthly Cost | Containers |
|----------|-------------|------------|
| Container Service (XL) | $160 | 10 max |
| 20x Container Services | $3,200 | 200 |
| **1x Lightsail Instance** | **$40** | **10-20** |
| **5x Lightsail Instances** | **$200** | **50-100** |

## Step 4: Deploy Your Actual Code

```bash
# Create deployment package
cat > deploy_package.sh << 'EOF'
#!/bin/bash

# Download your code
git clone https://github.com/yourusername/1stdibs-extractor.git
cd 1stdibs-extractor

# Or upload via SCP
# scp -r local-code/* ubuntu@YOUR_IP:~/1stdibs-extraction/

# Build production image
docker build -t 1stdibs-extractor .

# Run containers with proper config
for i in {1..10}; do
  docker run -d \
    --name extractor-$i \
    --memory="350m" \
    -v $(pwd)/data/container$i:/data \
    -e CONTAINER_ID=$i \
    -e URL_START=$((($i-1)*5000)) \
    -e URL_COUNT=5000 \
    1stdibs-extractor
done

# Monitor
docker ps
docker stats
EOF
```

## Step 5: Scale Horizontally

Need more processing power? Create more instances:

```bash
# From Lightsail Console or CLI
aws lightsail create-instances \
  --instance-names "extractor-2" "extractor-3" "extractor-4" \
  --availability-zone ap-southeast-1a \
  --blueprint-id ubuntu_20_04 \
  --bundle-id medium_2_0 \
  --user-data file://setup.sh
```

## Monitoring Dashboard

```bash
# Create simple monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
while true; do
  clear
  echo "=== Container Status ==="
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.CPUPerc}}\t{{.MemUsage}}"
  echo ""
  echo "=== Completed ==="
  ls -la data/*/extracted/*.json 2>/dev/null | wc -l
  sleep 5
done
EOF

chmod +x monitor.sh
./monitor.sh
```

## Alternative: Use AWS Batch from CloudShell

If you want managed containers, use AWS Batch instead:

```bash
# From AWS CloudShell
# Create compute environment
aws batch create-compute-environment \
  --compute-environment-name my-1stdibs-env \
  --type MANAGED \
  --service-role arn:aws:iam::YOUR_ACCOUNT:role/aws-batch-service-role

# Submit jobs
for i in {1..200}; do
  aws batch submit-job \
    --job-name "extractor-$i" \
    --job-queue my-queue \
    --job-definition extractor:1 \
    --container-overrides "environment=[{name=CHUNK_START,value=$((($i-1)*5000))}]"
done
```

## Summary

✅ **DO**: Use Lightsail Instances with Docker
❌ **DON'T**: Use Lightsail Container Service

**Why**: 
- 80% cheaper ($40 vs $3200/month)
- More flexible
- Better for batch processing
- Can run many containers per instance

**Quick Start**:
1. Create $40 Lightsail instance
2. Install Docker
3. Run 10-20 containers
4. Monitor progress
5. Scale by adding instances