# Git-Based Deployment Guide

## Step 1: Push Your Code to GitHub

```bash
# From your local machine (battlefield directory)
cd /Users/thahirkareem/local/battlefield

# Add all files and commit
git add .
git commit -m "Prepare for deployment"

# Push to GitHub
git push origin main

# Or create a new repository
# 1. Go to github.com and create new repo "1stdibs-extractor"
# 2. Then:
git remote add origin https://github.com/YOURUSERNAME/1stdibs-extractor.git
git push -u origin main
```

## Step 2: Clone on Your Instance

```bash
# SSH into your Lightsail instance
ssh ubuntu@YOUR_INSTANCE_IP

# Clone your repository
git clone https://github.com/YOURUSERNAME/1stdibs-extractor.git
cd 1stdibs-extractor

# Install Docker if needed
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# Logout and login again

# Build the image
docker build -f docker/Dockerfile -t 1stdibs-extractor .
```

## Step 3: Run Containers

```bash
# Single container test
docker run -d \
  --name extractor-1 \
  -e CONTAINER_ID=1 \
  -e URL_CHUNK_START=0 \
  -e URL_CHUNK_SIZE=100 \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/deployment/chunks/platinum_urls.txt:/app/data/urls_chunk.txt:ro \
  1stdibs-extractor

# Check logs
docker logs -f extractor-1
```

## Step 4: Scale with Multiple Containers

```bash
# Create data directories
mkdir -p data/{container1,container2,container3,container4,container5}

# Run 5 containers
for i in {1..5}; do
  docker run -d \
    --name extractor-$i \
    -e CONTAINER_ID=$i \
    -e URL_CHUNK_START=$(( ($i - 1) * 1000 )) \
    -e URL_CHUNK_SIZE=1000 \
    -e NTFY_TOPIC=1stdibs-$i \
    -v $(pwd)/data/container$i:/app/data \
    -v $(pwd)/deployment/chunks/platinum_urls.txt:/app/data/urls_chunk.txt:ro \
    1stdibs-extractor
done

echo "✅ Started 5 containers!"
docker ps
```

## Step 5: Monitor Progress

```bash
# View all containers
docker ps --filter name=extractor

# Follow logs of specific container
docker logs -f extractor-1

# Check extracted data
find data -name "*.json" | wc -l

# View container summary
cat data/container1/container_1_summary.json | jq .
```

## Step 6: Update Your Code

```bash
# When you make changes locally
git add .
git commit -m "Update extraction logic"
git push

# On the instance, update
cd ~/1stdibs-extractor
git pull
docker build -f docker/Dockerfile -t 1stdibs-extractor .

# Restart containers with new code
docker stop $(docker ps -q --filter name=extractor)
docker rm $(docker ps -aq --filter name=extractor)

# Run again with updated image
for i in {1..5}; do
  docker run -d --name extractor-$i \
    -e CONTAINER_ID=$i \
    -e URL_CHUNK_START=$(( ($i - 1) * 1000 )) \
    -e URL_CHUNK_SIZE=1000 \
    -v $(pwd)/data/container$i:/app/data \
    -v $(pwd)/deployment/chunks/platinum_urls.txt:/app/data/urls_chunk.txt:ro \
    1stdibs-extractor
done
```

## Alternative: Private Repository

If you want to keep code private:

```bash
# 1. Create private repo on GitHub
# 2. Generate personal access token (Settings > Developer settings > Personal access tokens)
# 3. Clone with token

git clone https://USERNAME:TOKEN@github.com/USERNAME/1stdibs-extractor.git

# Or set up SSH keys on the instance
ssh-keygen -t rsa -b 4096
cat ~/.ssh/id_rsa.pub
# Add this key to GitHub SSH keys
git clone git@github.com:USERNAME/1stdibs-extractor.git
```

## Complete Deployment Script

```bash
#!/bin/bash
# Save as deploy.sh and run after git clone

set -e
echo "🚀 Deploying 1stDibs Extractor..."

# Install Docker if needed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "Please logout and login again, then run this script again"
    exit 1
fi

# Build image
echo "📦 Building Docker image..."
docker build -f docker/Dockerfile -t 1stdibs-extractor .

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/{container1,container2,container3,container4,container5}

# Run containers
echo "🏃 Starting containers..."
CONTAINERS=${1:-5}
URLS_PER_CONTAINER=${2:-1000}

for i in $(seq 1 $CONTAINERS); do
    echo "Starting container $i..."
    docker run -d \
        --name extractor-$i \
        --memory="800m" \
        --cpus="0.5" \
        -e CONTAINER_ID=$i \
        -e URL_CHUNK_START=$(( ($i - 1) * $URLS_PER_CONTAINER )) \
        -e URL_CHUNK_SIZE=$URLS_PER_CONTAINER \
        -e NTFY_TOPIC=1stdibs-$i \
        -v $(pwd)/data/container$i:/app/data \
        -v $(pwd)/deployment/chunks/platinum_urls.txt:/app/data/urls_chunk.txt:ro \
        1stdibs-extractor
done

echo "✅ Deployment complete!"
echo ""
echo "📊 Monitor with:"
echo "  docker ps"
echo "  docker logs -f extractor-1"
echo "  find data -name '*.json' | wc -l"
echo ""
echo "🛑 Stop all with:"
echo "  docker stop \$(docker ps -q --filter name=extractor)"
```

## Usage

```bash
# On your instance after git clone
chmod +x deploy.sh

# Run 5 containers with 1000 URLs each
./deploy.sh 5 1000

# Run 10 containers with 500 URLs each
./deploy.sh 10 500
```