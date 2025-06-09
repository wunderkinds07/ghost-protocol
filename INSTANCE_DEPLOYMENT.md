# Instance Deployment Guide

## Prerequisites
- SSH access to Linux instance (Ubuntu/Debian preferred)
- Docker and Docker Compose installed
- At least 2GB RAM, 10GB disk space

## Step 1: Connect to Instance
```bash
ssh ubuntu@your-instance-ip
```

## Step 2: Install Docker (if needed)
```bash
# Update packages
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io docker-compose

# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again for group changes
exit
ssh ubuntu@your-instance-ip
```

## Step 3: Create Project Directory
```bash
mkdir -p ~/1stdibs-extraction
cd ~/1stdibs-extraction
```

## Step 4: Transfer Files
From your local machine:
```bash
# Create a tarball of necessary files
tar -czf deployment.tar.gz \
    src/ \
    docker/ \
    deployment/chunks/platinum_urls.txt \
    requirements.txt

# Transfer to instance
scp deployment.tar.gz ubuntu@your-instance-ip:~/1stdibs-extraction/

# Extract on instance
ssh ubuntu@your-instance-ip "cd ~/1stdibs-extraction && tar -xzf deployment.tar.gz"
```

## Step 5: Build Docker Image
```bash
# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim

RUN apt-get update && apt-get install -y wget curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY docker/*.py ./
COPY docker/config.json .

RUN mkdir -p /app/data/raw_html /app/data/extracted /app/data/logs

ENV PYTHONUNBUFFERED=1
CMD ["python", "entrypoint.py"]
EOF

# Build image
docker build -t 1stdibs-extractor .
```

## Step 6: Run Single Container
```bash
# Create data directory
mkdir -p data

# Run container with 100 URLs
docker run -d \
    --name extractor-1 \
    -e CONTAINER_ID=1 \
    -e URL_CHUNK_START=0 \
    -e URL_CHUNK_SIZE=100 \
    -e NTFY_TOPIC=my-1stdibs-test \
    -v $(pwd)/data:/app/data \
    -v $(pwd)/deployment/chunks/platinum_urls.txt:/app/data/urls_chunk.txt:ro \
    1stdibs-extractor

# Check logs
docker logs -f extractor-1
```

## Step 7: Run Multiple Containers
```bash
# Run 5 containers processing different URL chunks
for i in {1..5}; do
    START=$(( ($i - 1) * 1000 ))
    docker run -d \
        --name extractor-$i \
        -e CONTAINER_ID=$i \
        -e URL_CHUNK_START=$START \
        -e URL_CHUNK_SIZE=1000 \
        -v $(pwd)/data/container$i:/app/data \
        -v $(pwd)/deployment/chunks/platinum_urls.txt:/app/data/urls_chunk.txt:ro \
        1stdibs-extractor
done
```

## Step 8: Monitor Progress
```bash
# View all running containers
docker ps

# Check specific container logs
docker logs -f extractor-1

# Monitor resource usage
docker stats

# Check extracted data
ls -la data/container1/extracted/

# View summary
cat data/container1/container_1_summary.json | jq .
```

## Step 9: Using Docker Compose (Alternative)
```yaml
# docker-compose.yml
version: '3.8'

services:
  extractor-1:
    image: 1stdibs-extractor
    container_name: extractor-1
    environment:
      - CONTAINER_ID=1
      - URL_CHUNK_START=0
      - URL_CHUNK_SIZE=1000
      - NTFY_TOPIC=1stdibs-1
    volumes:
      - ./data/container1:/app/data
      - ./urls.txt:/app/data/urls_chunk.txt:ro

  extractor-2:
    image: 1stdibs-extractor
    container_name: extractor-2
    environment:
      - CONTAINER_ID=2
      - URL_CHUNK_START=1000
      - URL_CHUNK_SIZE=1000
      - NTFY_TOPIC=1stdibs-2
    volumes:
      - ./data/container2:/app/data
      - ./urls.txt:/app/data/urls_chunk.txt:ro
```

Run with:
```bash
docker-compose up -d
docker-compose logs -f
```

## Step 10: Cleanup
```bash
# Stop all containers
docker stop $(docker ps -q --filter name=extractor)

# Remove containers
docker rm $(docker ps -aq --filter name=extractor)

# Remove image (optional)
docker rmi 1stdibs-extractor
```

## Configuration Options

### Environment Variables
- `CONTAINER_ID`: Unique identifier for the container
- `URL_CHUNK_START`: Starting index in URL list
- `URL_CHUNK_SIZE`: Number of URLs to process
- `NTFY_TOPIC`: Notification topic (optional)
- `S3_BUCKET`: AWS S3 bucket for uploads (optional)
- `DISCORD_WEBHOOK`: Discord notification URL (optional)

### Performance Tuning
- Small instance (1-2 CPU): Run 1-2 containers
- Medium instance (4 CPU): Run 3-5 containers  
- Large instance (8+ CPU): Run 6-10 containers

### Monitoring URLs
- ntfy.sh: https://ntfy.sh/YOUR_TOPIC
- Container logs: `docker logs -f extractor-1`
- Progress files: `data/container*/container_*_checkpoint.json`

## Troubleshooting

### Container exits immediately
Check logs: `docker logs extractor-1`

### Permission denied errors
Ensure data directory has correct permissions:
```bash
chmod -R 755 data/
```

### Out of memory
Reduce number of concurrent containers or URL chunk size

### Network timeouts
Check instance security groups allow outbound HTTPS (port 443)