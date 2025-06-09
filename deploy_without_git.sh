#!/bin/bash
# Deploy directly to instance without GitHub

INSTANCE_IP=${1:-""}
if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: ./deploy_without_git.sh YOUR_INSTANCE_IP"
    exit 1
fi

echo "🚀 Direct deployment to $INSTANCE_IP"

# Create deployment package
echo "📦 Creating deployment package..."
tar -czf deployment.tar.gz \
    src/ \
    docker/ \
    deployment/chunks/platinum_urls.txt \
    requirements.txt \
    CLAUDE.md \
    README.md

# Transfer to instance
echo "📤 Transferring package..."
scp deployment.tar.gz ubuntu@$INSTANCE_IP:~/

# Create deployment script
cat > setup_instance.sh << 'SCRIPT'
#!/bin/bash
set -e

echo "🔧 Setting up instance..."

# Install Docker
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "⚠️ Please logout and login again, then re-run this script"
    exit 1
fi

# Extract deployment
tar -xzf deployment.tar.gz
cd ~/

# Create Dockerfile in root
cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
RUN apt-get update && apt-get install -y wget curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ./src/
COPY docker/entrypoint.py ./
COPY docker/notifier.py ./
COPY docker/s3_uploader.py ./
COPY docker/config.json ./
RUN mkdir -p /app/data/raw_html /app/data/extracted /app/data/logs
ENV PYTHONUNBUFFERED=1
CMD ["python", "entrypoint.py"]
EOF

# Build image
echo "🐳 Building Docker image..."
docker build -t 1stdibs-extractor .

# Create test script
cat > test_container.sh << 'TEST'
#!/bin/bash
echo "🧪 Testing container..."

# Run test container with 5 URLs
docker run -d \
    --name extractor-test \
    -e CONTAINER_ID=test \
    -e URL_CHUNK_START=0 \
    -e URL_CHUNK_SIZE=5 \
    -e NTFY_TOPIC=1stdibs-test \
    -v $(pwd)/data:/app/data \
    -v $(pwd)/deployment/chunks/platinum_urls.txt:/app/data/urls_chunk.txt:ro \
    1stdibs-extractor

echo "⏳ Container started. Checking logs..."
sleep 5
docker logs extractor-test

echo ""
echo "📊 Container status:"
docker ps --filter name=extractor-test

echo ""
echo "To follow logs: docker logs -f extractor-test"
echo "To stop test: docker stop extractor-test && docker rm extractor-test"
TEST

chmod +x test_container.sh

echo "✅ Setup complete!"
echo ""
echo "🧪 Run test: ./test_container.sh"
echo "📊 Monitor: docker logs -f extractor-test"
echo "📁 Results: ls -la data/"
SCRIPT

# Transfer and run setup
echo "🔧 Running setup on instance..."
scp setup_instance.sh ubuntu@$INSTANCE_IP:~/
ssh ubuntu@$INSTANCE_IP "chmod +x setup_instance.sh && ./setup_instance.sh"

# Cleanup
rm deployment.tar.gz setup_instance.sh

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔗 Next steps:"
echo "1. SSH into instance: ssh ubuntu@$INSTANCE_IP"
echo "2. Test container: ./test_container.sh"
echo "3. Monitor logs: docker logs -f extractor-test"
echo "4. Scale up: Run multiple containers with different CONTAINER_ID"