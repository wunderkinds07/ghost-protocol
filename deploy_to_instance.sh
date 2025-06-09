#!/bin/bash
# Deploy script for 1stDibs data extraction containers

set -e  # Exit on error

echo "🚀 1stDibs Container Deployment Script"
echo "====================================="

# Configuration
REMOTE_USER="${1:-ubuntu}"
REMOTE_HOST="${2:-}"
REMOTE_PATH="${3:-/home/$REMOTE_USER/1stdibs-extraction}"

if [ -z "$REMOTE_HOST" ]; then
    echo "Usage: ./deploy_to_instance.sh [user] <host> [remote_path]"
    echo "Example: ./deploy_to_instance.sh ubuntu 54.123.45.67"
    exit 1
fi

echo "📋 Deployment Configuration:"
echo "  Remote: $REMOTE_USER@$REMOTE_HOST"
echo "  Path: $REMOTE_PATH"
echo ""

# Create deployment package
echo "📦 Creating deployment package..."
rm -rf deploy_package
mkdir -p deploy_package

# Copy necessary files
cp -r src deploy_package/
cp -r docker deploy_package/
cp requirements.txt deploy_package/
cp -r deployment/chunks deploy_package/  # URL chunks

# Create setup script
cat > deploy_package/setup.sh << 'EOF'
#!/bin/bash
set -e

echo "🔧 Setting up environment..."

# Update system
sudo apt-get update
sudo apt-get install -y docker.io docker-compose python3-pip

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Environment setup complete!"
EOF

# Create run script
cat > deploy_package/run.sh << 'EOF'
#!/bin/bash

# Configuration
CONTAINERS=${1:-1}
URLS_PER_CONTAINER=${2:-1000}
NOTIFICATION_URL=${3:-}

echo "🐳 Starting $CONTAINERS container(s)..."
echo "📊 Processing $URLS_PER_CONTAINER URLs per container"

# Create data directory
mkdir -p data

# Run containers
for i in $(seq 1 $CONTAINERS); do
    CONTAINER_NAME="extractor-$i"
    START_INDEX=$(( ($i - 1) * $URLS_PER_CONTAINER ))
    
    echo "Starting container $i (URLs $START_INDEX to $(($START_INDEX + $URLS_PER_CONTAINER - 1)))"
    
    docker run -d \
        --name $CONTAINER_NAME \
        -e CONTAINER_ID=$i \
        -e URL_CHUNK_START=$START_INDEX \
        -e URL_CHUNK_SIZE=$URLS_PER_CONTAINER \
        -e NTFY_TOPIC=1stdibs-extraction-$i \
        -v $(pwd)/data/container$i:/app/data \
        -v $(pwd)/chunks/platinum_urls.txt:/app/data/urls_chunk.txt:ro \
        1stdibs-extractor
done

echo "✅ All containers started!"
echo ""
echo "Monitor with:"
echo "  docker ps"
echo "  docker logs -f extractor-1"
echo ""
echo "Stop all with:"
echo "  docker stop $(docker ps -q --filter name=extractor)"
EOF

# Create monitor script
cat > deploy_package/monitor.sh << 'EOF'
#!/bin/bash

echo "📊 Container Monitoring Dashboard"
echo "================================"

while true; do
    clear
    echo "📊 Container Status ($(date))"
    echo "================================"
    
    # Show running containers
    docker ps --filter name=extractor --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
    
    echo ""
    echo "📈 Progress Summary:"
    
    # Check progress from each container
    for i in $(seq 1 10); do
        if [ -f "data/container$i/container_${i}_checkpoint.json" ]; then
            echo -n "Container $i: "
            cat "data/container$i/container_${i}_checkpoint.json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f\"{data['processed']} processed, {data['stats']['success']} success, {data['stats']['failed']} failed\")
"
        fi
    done
    
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 5
done
EOF

chmod +x deploy_package/*.sh

# Create minimal docker-compose
cat > deploy_package/docker-compose.yml << 'EOF'
version: '3.8'

services:
  extractor:
    build: .
    image: 1stdibs-extractor
    environment:
      - CONTAINER_ID=1
      - URL_CHUNK_START=0
      - URL_CHUNK_SIZE=1000
    volumes:
      - ./data:/app/data
EOF

# Create Dockerfile in package root
cat > deploy_package/Dockerfile << 'EOF'
FROM python:3.9-slim

RUN apt-get update && apt-get install -y wget curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY docker/entrypoint.py .
COPY docker/notifier.py .
COPY docker/s3_uploader.py .
COPY docker/config.json .

RUN mkdir -p /app/data/raw_html /app/data/extracted /app/data/logs

ENV PYTHONUNBUFFERED=1
CMD ["python", "entrypoint.py"]
EOF

# Transfer to remote
echo "📤 Transferring files to remote instance..."
ssh $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_PATH"
scp -r deploy_package/* $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/

# Setup on remote
echo "🔧 Running setup on remote..."
ssh $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_PATH && bash setup.sh"

# Build Docker image
echo "🐳 Building Docker image on remote..."
ssh $REMOTE_USER@$REMOTE_HOST "cd $REMOTE_PATH && docker build -t 1stdibs-extractor ."

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. SSH into your instance:"
echo "   ssh $REMOTE_USER@$REMOTE_HOST"
echo ""
echo "2. Navigate to deployment:"
echo "   cd $REMOTE_PATH"
echo ""
echo "3. Run containers:"
echo "   ./run.sh 5 1000  # Run 5 containers, 1000 URLs each"
echo ""
echo "4. Monitor progress:"
echo "   ./monitor.sh"
echo ""
echo "5. Check logs:"
echo "   docker logs -f extractor-1"
echo ""
echo "6. View results:"
echo "   ls data/container1/extracted/"

# Cleanup
rm -rf deploy_package