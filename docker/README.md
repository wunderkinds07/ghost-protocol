# 1stDibs Data Extraction Docker Container

## Overview
This Docker container solution processes 1stDibs product URLs in chunks of 5,000, extracting and saving:
- Raw HTML files (compressed)
- Structured product data (JSON)
- Processing logs and summaries

Each container operates independently, making it perfect for distributed processing across multiple machines.

## Architecture

```
Container Structure:
├── /app/data/
│   ├── raw_html/        # Compressed HTML files (f_12345.html.gz)
│   ├── extracted/       # Product JSON files (f_12345.json)
│   └── logs/           # Processing logs
│
└── Product ID Lineage: All files use product_id (e.g., f_10001073) as identifier
```

## Quick Start

### 1. Build the Docker Image
```bash
cd docker
docker build -t 1stdibs-extractor:latest -f Dockerfile ..
```

### 2. Deploy Containers

**Option A: Using Docker Compose (Recommended for local)**
```bash
docker-compose up -d
```

**Option B: Deploy Individual Containers**
```bash
# Container 1: URLs 0-4999
docker run -d \
  --name 1stdibs-extractor-1 \
  -e CONTAINER_ID=1 \
  -e URL_CHUNK_START=0 \
  -e URL_CHUNK_SIZE=5000 \
  -v $(pwd)/data/container1:/app/data \
  1stdibs-extractor:latest

# Container 2: URLs 5000-9999
docker run -d \
  --name 1stdibs-extractor-2 \
  -e CONTAINER_ID=2 \
  -e URL_CHUNK_START=5000 \
  -e URL_CHUNK_SIZE=5000 \
  -v $(pwd)/data/container2:/app/data \
  1stdibs-extractor:latest
```

**Option C: Use Deployment Script**
```bash
chmod +x deploy.sh
./deploy.sh
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| CONTAINER_ID | Unique container identifier | 1 |
| URL_CHUNK_START | Starting index for URLs | 0 |
| URL_CHUNK_SIZE | Number of URLs to process | 5000 |

## Output Structure

Each product (e.g., product_id: f_10001073) generates:

**1. Raw HTML File:**
```
data/container1/raw_html/f_10001073.html.gz
```

**2. Extracted JSON:**
```json
data/container1/extracted/f_10001073.json
{
  "url": "https://www.1stdibs.com/...",
  "extraction_status": "success",
  "data": {
    "product_info": {
      "title": "Italian Parcel Ebonized Walnut Mirror",
      "product_id": "f_10001073",
      "description": "...",
      "category": "Pier Mirrors"
    },
    "specifications": {
      "dimensions": {"height": "34.5", "width": "48", "depth": "3"},
      "materials": "Walnut",
      "origin": "Italy",
      "period": "18th Century",
      "condition": "Good"
    },
    "pricing": {
      "currency": "USD",
      "price": "5400",
      "multi_currency": {...}
    },
    "images": [
      "https://a.1stdibscdn.com/.../10001073_master.jpg",
      ...
    ]
  },
  "extraction_metadata": {
    "container_id": "1",
    "extraction_time": "2025-01-09T12:00:00",
    "html_size_bytes": 1024000,
    "product_id": "f_10001073"
  }
}
```

## Monitoring Progress

**Check Container Status:**
```bash
docker ps | grep 1stdibs
```

**View Logs:**
```bash
docker logs -f 1stdibs-extractor-1
```

**Check Progress:**
```bash
cat data/container1/container_1_checkpoint.json
```

**Monitor All Containers:**
```bash
docker-compose logs -f  # If using compose
```

## Scaling Options

### Local Machine (Multiple Containers)
```bash
# Deploy 10 containers (50K URLs total)
for i in {1..10}; do
  docker run -d \
    --name 1stdibs-extractor-$i \
    -e CONTAINER_ID=$i \
    -e URL_CHUNK_START=$((($i-1)*5000)) \
    -e URL_CHUNK_SIZE=5000 \
    -v $(pwd)/data/container$i:/app/data \
    1stdibs-extractor:latest
done
```

### Cloud Deployment (AWS/GCP/Azure)

**1. Push Image to Registry:**
```bash
# AWS ECR
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URI
docker tag 1stdibs-extractor:latest $ECR_URI/1stdibs-extractor:latest
docker push $ECR_URI/1stdibs-extractor:latest

# Google Container Registry
docker tag 1stdibs-extractor:latest gcr.io/$PROJECT_ID/1stdibs-extractor:latest
docker push gcr.io/$PROJECT_ID/1stdibs-extractor:latest
```

**2. Deploy on Cloud Instances:**
```bash
# Run on EC2/GCE/Azure VM
docker run -d \
  --restart unless-stopped \
  -e CONTAINER_ID=$INSTANCE_ID \
  -e URL_CHUNK_START=$START_INDEX \
  -e URL_CHUNK_SIZE=5000 \
  -v /data/extraction:/app/data \
  $IMAGE_URI
```

## S3 Upload (Post-Processing)

After extraction completes, upload to S3:

```bash
# Install AWS CLI if needed
pip install boto3

# Upload all container data
python s3_upload.py --bucket your-bucket-name --region us-east-1
```

S3 Structure:
```
s3://your-bucket/
└── 1stdibs-extraction/
    ├── container-1/
    │   ├── raw_html/
    │   │   ├── f_10001073.html.gz
    │   │   └── ...
    │   ├── extracted/
    │   │   ├── f_10001073.json
    │   │   └── ...
    │   └── container_1_summary.json
    └── upload_summary.json
```

## Performance Metrics

- **Processing Rate**: ~60-80 URLs/minute per container
- **Storage**: ~1MB per product (HTML + JSON)
- **Memory Usage**: ~500MB per container
- **Network**: Rate-limited to avoid overwhelming servers

## Troubleshooting

**Container Crashes:**
```bash
docker logs 1stdibs-extractor-1 --tail 100
```

**Restart Failed Container:**
```bash
docker restart 1stdibs-extractor-1
```

**Check Disk Space:**
```bash
du -sh data/container*/
```

**Resume from Checkpoint:**
Containers automatically save progress. Simply restart to continue.

## Best Practices

1. **Rate Limiting**: Default 0.5-1.0s delay between requests
2. **Error Handling**: Failed URLs logged, can be reprocessed
3. **Storage**: Use SSD for better I/O performance
4. **Monitoring**: Check logs regularly for errors
5. **Backup**: Sync extracted data to S3/cloud storage

## Example Deployment Scenarios

**Scenario 1: Process 50K URLs on Single Machine**
```bash
# Deploy 10 containers
docker-compose up -d --scale extractor=10
```

**Scenario 2: Distributed Processing (5 machines, 200K URLs)**
```bash
# On each machine, run 8 containers (40 total)
for i in {1..8}; do
  GLOBAL_ID=$((($MACHINE_ID-1)*8 + $i))
  docker run -d ... -e CONTAINER_ID=$GLOBAL_ID ...
done
```

**Scenario 3: Kubernetes Deployment**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: 1stdibs-extractor
spec:
  parallelism: 20
  template:
    spec:
      containers:
      - name: extractor
        image: 1stdibs-extractor:latest
        env:
        - name: CONTAINER_ID
          value: "$(POD_NAME)"
```

## Support

- Check logs in `/app/data/logs/`
- Summary files in `/app/data/container_X_summary.json`
- Failed URLs logged for reprocessing