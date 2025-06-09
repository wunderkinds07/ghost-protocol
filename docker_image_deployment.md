# How to Get Your Docker Image on the Server

## Option 1: Build Directly on the Instance (Easiest)

```bash
# 1. SSH into your Lightsail instance
ssh ubuntu@YOUR_INSTANCE_IP

# 2. Clone your code or create it
mkdir ~/1stdibs-extraction
cd ~/1stdibs-extraction

# 3. Create the necessary files directly
cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
RUN apt-get update && apt-get install -y wget curl && rm -rf /var/lib/apt/lists/*
RUN pip install requests beautifulsoup4 lxml pandas
COPY . .
CMD ["python", "main.py"]
EOF

# 4. Create a simple test script
cat > main.py << 'EOF'
import requests
from bs4 import BeautifulSoup
import json
import os

print(f"Container {os.environ.get('CONTAINER_ID', '1')} started!")
# Add your extraction logic here
EOF

# 5. Build the image
docker build -t 1stdibs-extractor .

# 6. Run it
docker run -d --name test-1 -e CONTAINER_ID=1 1stdibs-extractor
```

## Option 2: Transfer Files via SCP

```bash
# From your LOCAL machine
# 1. Create a deployment package
cd /Users/thahirkareem/local/battlefield
tar -czf deploy.tar.gz \
  src/ \
  docker/entrypoint.py \
  docker/notifier.py \
  docker/s3_uploader.py \
  docker/config.json \
  docker/requirements.txt \
  deployment/chunks/platinum_urls.txt

# 2. Transfer to instance
scp deploy.tar.gz ubuntu@YOUR_INSTANCE_IP:~/

# 3. On the instance, extract and build
ssh ubuntu@YOUR_INSTANCE_IP
tar -xzf deploy.tar.gz
docker build -f docker/Dockerfile -t 1stdibs-extractor .
```

## Option 3: Use Docker Hub (Public Registry)

```bash
# On your LOCAL machine
# 1. Build and tag image
docker build -t yourusername/1stdibs-extractor:latest .

# 2. Push to Docker Hub
docker login
docker push yourusername/1stdibs-extractor:latest

# 3. On the instance, pull image
ssh ubuntu@YOUR_INSTANCE_IP
docker pull yourusername/1stdibs-extractor:latest
docker run -d --name extractor-1 yourusername/1stdibs-extractor:latest
```

## Option 4: Use AWS ECR (Private Registry)

```bash
# 1. Create ECR repository (from CloudShell or local)
aws ecr create-repository --repository-name 1stdibs-extractor --region ap-southeast-1

# 2. Get login token
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com

# 3. Build, tag, and push
docker build -t 1stdibs-extractor .
docker tag 1stdibs-extractor:latest YOUR_ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com/1stdibs-extractor:latest
docker push YOUR_ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com/1stdibs-extractor:latest

# 4. On instance, pull from ECR
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com
docker pull YOUR_ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com/1stdibs-extractor:latest
```

## Option 5: Quick Test Without Your Code

```bash
# Use a pre-built web scraper image for testing
docker run -d \
  --name scraper-test \
  -e TARGET_URL="https://www.1stdibs.com/furniture/lighting/chandeliers-pendant-lights/" \
  scrapinghub/splash

# Or create a minimal test container
docker run -d \
  --name test-extractor \
  python:3.9-slim \
  python -c "import time; print('Extracting...'); time.sleep(3600)"
```

## Recommended: Simple Transfer Script

```bash
# Save this as transfer_to_instance.sh on your local machine
#!/bin/bash

INSTANCE_IP=$1
if [ -z "$INSTANCE_IP" ]; then
  echo "Usage: ./transfer_to_instance.sh YOUR_INSTANCE_IP"
  exit 1
fi

# Create minimal package
cat > temp_deploy.sh << 'SCRIPT'
#!/bin/bash
mkdir -p extraction/{src,docker}

# Create Dockerfile
cat > extraction/Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
RUN pip install requests beautifulsoup4 lxml
COPY main.py .
CMD ["python", "main.py"]
EOF

# Create main script
cat > extraction/main.py << 'EOF'
import os
import time
import requests
from bs4 import BeautifulSoup

container_id = os.environ.get('CONTAINER_ID', '1')
url_start = int(os.environ.get('URL_START', '0'))
url_count = int(os.environ.get('URL_COUNT', '10'))

print(f"Container {container_id} processing URLs {url_start} to {url_start + url_count}")

# Simple test URLs
test_urls = [
    "https://www.1stdibs.com/furniture/lighting/chandeliers-pendant-lights/id-f_1234/",
    "https://www.1stdibs.com/furniture/seating/chairs/id-f_5678/",
]

for i, url in enumerate(test_urls[:url_count]):
    print(f"Processing URL {i+1}: {url}")
    try:
        # Add your scraping logic here
        time.sleep(1)  # Simulate work
        print(f"✓ Processed URL {i+1}")
    except Exception as e:
        print(f"✗ Failed URL {i+1}: {e}")

print(f"Container {container_id} completed!")
SCRIPT

# Transfer and run
scp temp_deploy.sh ubuntu@$INSTANCE_IP:~/
ssh ubuntu@$INSTANCE_IP "bash temp_deploy.sh && cd extraction && docker build -t extractor . && docker run -d --name test-1 -e CONTAINER_ID=1 extractor"

echo "✅ Deployment complete! Check with: ssh ubuntu@$INSTANCE_IP 'docker logs test-1'"
```

## Quick Start Commands

```bash
# 1. After SSH into instance
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker $USER
# Logout and login again

# 2. Create and run a test container
docker run -d --name test \
  -e CONTAINER_ID=1 \
  python:3.9 \
  python -c "print('Container works!'); import time; time.sleep(60)"

# 3. Check it's running
docker ps
docker logs test
```

The easiest approach is Option 1 - build directly on the instance!