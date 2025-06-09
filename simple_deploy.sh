#!/bin/bash
# Simple deployment script for ghost-protocol
# Deploy to any instance via SSH with specific chunk

set -e

# Configuration
CHUNK_ID=${1:-1}
INSTANCE_IP=${2:-}
SSH_KEY=${3:-~/.ssh/id_rsa}
REMOTE_USER=${4:-ubuntu}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Usage
if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: $0 <chunk_id> <instance_ip> [ssh_key] [remote_user]"
    echo "Example: $0 1 54.123.45.67"
    echo "Example: $0 3 54.123.45.67 ~/.ssh/my-key.pem ec2-user"
    exit 1
fi

# Check if chunk exists
CHUNK_FILE="chunks/urls_chunk_$(printf "%04d" $CHUNK_ID).txt"
if [ ! -f "$CHUNK_FILE" ]; then
    echo -e "${RED}Error: Chunk file $CHUNK_FILE not found${NC}"
    echo "Run 'python prepare_chunks.py' first to create chunks"
    exit 1
fi

echo -e "${GREEN}=== Ghost Protocol Simple Deploy ===${NC}"
echo "Deploying chunk $CHUNK_ID to $INSTANCE_IP"
echo "Chunk file: $CHUNK_FILE"
echo "SSH Key: $SSH_KEY"
echo "Remote user: $REMOTE_USER"
echo ""

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
DEPLOY_DIR="deploy_package_chunk_$CHUNK_ID"
rm -rf $DEPLOY_DIR
mkdir -p $DEPLOY_DIR

# Copy necessary files
cp -r docker/* $DEPLOY_DIR/
cp $CHUNK_FILE $DEPLOY_DIR/urls_chunk.txt
cp requirements.txt $DEPLOY_DIR/

# Create instance-specific config
cat > $DEPLOY_DIR/instance_config.json << EOF
{
    "chunk_id": $CHUNK_ID,
    "chunk_file": "urls_chunk.txt",
    "instance_ip": "$INSTANCE_IP",
    "deployment_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Create deployment script for the instance
cat > $DEPLOY_DIR/run_on_instance.sh << 'SCRIPT'
#!/bin/bash
set -e

echo "=== Setting up Ghost Protocol on instance ==="

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create working directory
sudo mkdir -p /opt/ghost-protocol
sudo chown $USER:$USER /opt/ghost-protocol
cd /opt/ghost-protocol

# Copy files
cp -r ~/ghost-deploy/* .

# Set up environment
export CHUNK_FILE=urls_chunk.txt
export CONTAINER_NAME="ghost-chunk-$(cat instance_config.json | grep chunk_id | cut -d: -f2 | tr -d ' ,"')"

# Update docker-compose.yml to use single container
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  processor:
    build: .
    container_name: ${CONTAINER_NAME}
    environment:
      - URLS_FILE=/app/urls_chunk.txt
      - CONTAINER_ID=${CONTAINER_NAME}
      - OUTPUT_DIR=/app/data
    volumes:
      - ./data:/app/data
      - ./urls_chunk.txt:/app/urls_chunk.txt:ro
    restart: unless-stopped
EOF

# Start processing
echo "Starting Ghost Protocol processor..."
docker-compose up -d --build

echo "=== Deployment complete ==="
echo "Container name: $CONTAINER_NAME"
echo "Check logs: docker logs -f $CONTAINER_NAME"
echo "Check status: docker ps"
SCRIPT

chmod +x $DEPLOY_DIR/run_on_instance.sh

# Create tarball
echo -e "${YELLOW}Creating deployment archive...${NC}"
tar -czf ${DEPLOY_DIR}.tar.gz $DEPLOY_DIR/

# Deploy to instance
echo -e "${YELLOW}Deploying to instance...${NC}"
scp -i $SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_DIR}.tar.gz $REMOTE_USER@$INSTANCE_IP:~/

echo -e "${YELLOW}Extracting and running on instance...${NC}"
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_USER@$INSTANCE_IP << EOF
    tar -xzf ${DEPLOY_DIR}.tar.gz
    mv $DEPLOY_DIR ghost-deploy
    cd ghost-deploy
    bash run_on_instance.sh
EOF

# Cleanup
rm -rf $DEPLOY_DIR ${DEPLOY_DIR}.tar.gz

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo "Instance: $INSTANCE_IP"
echo "Chunk: $CHUNK_ID"
echo ""
echo "Useful commands:"
echo "  SSH to instance: ssh -i $SSH_KEY $REMOTE_USER@$INSTANCE_IP"
echo "  Check logs: ssh -i $SSH_KEY $REMOTE_USER@$INSTANCE_IP 'docker logs -f ghost-chunk-$CHUNK_ID'"
echo "  Check status: ssh -i $SSH_KEY $REMOTE_USER@$INSTANCE_IP 'docker ps'"
echo "  Get results: scp -i $SSH_KEY -r $REMOTE_USER@$INSTANCE_IP:/opt/ghost-protocol/data ./results_chunk_$CHUNK_ID"