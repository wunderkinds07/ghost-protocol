#!/bin/bash
# Complete Git-based deployment script
# Usage: ./deploy_via_git.sh [github_repo_url] [instance_ip]

REPO_URL=${1:-"https://github.com/YOURUSERNAME/1stdibs-extractor.git"}
INSTANCE_IP=${2:-""}

if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: ./deploy_via_git.sh [repo_url] <instance_ip>"
    echo "Example: ./deploy_via_git.sh https://github.com/user/repo.git 54.123.45.67"
    exit 1
fi

echo "🚀 Git-based Deployment to Lightsail Instance"
echo "============================================="
echo "Repository: $REPO_URL"
echo "Instance: $INSTANCE_IP"
echo ""

# Create deployment script
cat > temp_git_deploy.sh << 'SCRIPT'
#!/bin/bash
set -e

echo "📦 Setting up environment..."

# Install Docker if needed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "⚠️  Please logout and login again to apply Docker permissions"
    echo "Then run: git clone REPO_URL && cd REPO_NAME && ./deploy.sh"
    exit 1
fi

# Install git if needed
if ! command -v git &> /dev/null; then
    sudo apt update
    sudo apt install -y git
fi

# Clone repository
REPO_URL="$1"
REPO_NAME=$(basename "$REPO_URL" .git)

if [ -d "$REPO_NAME" ]; then
    echo "📂 Repository exists, updating..."
    cd "$REPO_NAME"
    git pull
else
    echo "📥 Cloning repository..."
    git clone "$REPO_URL"
    cd "$REPO_NAME"
fi

echo "🔨 Building Docker image..."
docker build -f docker/Dockerfile -t 1stdibs-extractor . || {
    echo "❌ Docker build failed. Creating simple fallback..."
    
    # Create fallback Dockerfile if original fails
    cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
RUN pip install requests beautifulsoup4 lxml pandas
COPY src/ ./src/
COPY docker/entrypoint.py ./
COPY docker/notifier.py ./
COPY docker/s3_uploader.py ./
RUN mkdir -p /app/data/raw_html /app/data/extracted /app/data/logs
ENV PYTHONUNBUFFERED=1
CMD ["python", "entrypoint.py"]
EOF
    
    docker build -t 1stdibs-extractor .
}

echo "📁 Setting up data directories..."
mkdir -p data/{container1,container2,container3,container4,container5}

echo "🏃 Starting test container..."
docker run -d \
    --name extractor-test \
    -e CONTAINER_ID=test \
    -e URL_CHUNK_START=0 \
    -e URL_CHUNK_SIZE=5 \
    -v $(pwd)/data/container1:/app/data \
    1stdibs-extractor

echo "⏳ Waiting for test container..."
sleep 10

echo "📊 Test container status:"
docker ps --filter name=extractor-test
echo ""
echo "📄 Test container logs:"
docker logs extractor-test
echo ""

read -p "Test looks good? Start production containers? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting production containers..."
    
    # Stop test container
    docker stop extractor-test && docker rm extractor-test
    
    # Start production containers
    for i in {1..5}; do
        echo "Starting container $i..."
        docker run -d \
            --name extractor-$i \
            --memory="800m" \
            --cpus="0.4" \
            -e CONTAINER_ID=$i \
            -e URL_CHUNK_START=$(( ($i - 1) * 1000 )) \
            -e URL_CHUNK_SIZE=1000 \
            -e NTFY_TOPIC=1stdibs-$i \
            -v $(pwd)/data/container$i:/app/data \
            1stdibs-extractor
    done
    
    echo "✅ Production deployment complete!"
    echo ""
    echo "📊 Monitor with:"
    echo "  docker ps"
    echo "  docker logs -f extractor-1"
    echo "  watch 'find data -name \"*.json\" | wc -l'"
else
    echo "🛑 Stopping test container..."
    docker stop extractor-test && docker rm extractor-test
fi

echo ""
echo "🔧 Useful commands:"
echo "  # View all containers"
echo "  docker ps --filter name=extractor"
echo ""
echo "  # Stop all containers"
echo "  docker stop \$(docker ps -q --filter name=extractor)"
echo ""
echo "  # View progress"
echo "  ls -la data/container*/extracted/"
echo ""
echo "  # Update code"
echo "  git pull && docker build -t 1stdibs-extractor ."
SCRIPT

# Transfer script to instance
echo "📤 Transferring deployment script..."
scp temp_git_deploy.sh ubuntu@$INSTANCE_IP:~/git_deploy.sh

# Run deployment
echo "🏃 Running deployment on instance..."
ssh ubuntu@$INSTANCE_IP "chmod +x git_deploy.sh && ./git_deploy.sh '$REPO_URL'"

# Cleanup
rm temp_git_deploy.sh

echo ""
echo "✅ Git deployment initiated!"
echo ""
echo "🔗 Next steps:"
echo "1. SSH into instance: ssh ubuntu@$INSTANCE_IP"
echo "2. Check container status: docker ps"
echo "3. Monitor logs: docker logs -f extractor-1"
echo "4. View progress: find data -name '*.json' | wc -l"