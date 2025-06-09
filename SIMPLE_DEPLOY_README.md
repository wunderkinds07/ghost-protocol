# Simple Deployment Guide for Ghost Protocol

This guide shows how to deploy Ghost Protocol across multiple instances with automatic URL chunking (5000 URLs per instance).

## Quick Start

### 1. Prepare URL Chunks

First, split your URLs into chunks of 5000 each:

```bash
# If you have the 1M URLs file
python prepare_chunks.py 1m-urls-1stdibs-raw.txt 5000 chunks

# Or for testing with a smaller file
python prepare_chunks.py test_urls.txt 5000 chunks
```

This creates:
- `chunks/` directory with numbered chunk files
- `chunks/chunks_manifest.json` with chunk metadata

### 2. Deploy to Single Instance

Deploy a specific chunk to one instance:

```bash
# Deploy chunk 1 to an instance
./simple_deploy.sh 1 54.123.45.67

# With custom SSH key
./simple_deploy.sh 1 54.123.45.67 ~/.ssh/my-key.pem

# With custom user (e.g., for AWS)
./simple_deploy.sh 1 54.123.45.67 ~/.ssh/my-key.pem ec2-user
```

### 3. Deploy to Multiple Instances

Create an `instances.txt` file with one IP per line:

```
54.123.45.67
54.123.45.68
54.123.45.69
```

Then deploy chunks across all instances:

```bash
# Deploy all chunks across instances
./deploy_multi_instance.sh instances.txt

# With custom SSH key
./deploy_multi_instance.sh instances.txt ~/.ssh/my-key.pem

# With custom user
./deploy_multi_instance.sh instances.txt ~/.ssh/my-key.pem ec2-user
```

The script automatically:
- Distributes chunks across instances (round-robin)
- Deploys Docker containers
- Tracks deployment status

### 4. Monitor Progress

Check individual instances:

```bash
# SSH to instance
ssh -i ~/.ssh/my-key.pem ubuntu@54.123.45.67

# Check container status
docker ps

# View logs
docker logs -f ghost-chunk-1

# Check processing progress
ls -la /opt/ghost-protocol/data/extracted/ | wc -l
```

### 5. Collect Results

After processing completes, collect all results:

```bash
# Collect from all instances
./collect_results.sh instances.txt

# With custom settings
./collect_results.sh instances.txt ~/.ssh/my-key.pem ubuntu results_directory
```

### 6. Merge and Analyze Data

Merge all collected data into a single dataset:

```bash
# Merge all extracted products
python merge_extracted_data.py collected_results_20240109_143022/

# This creates:
# - merged_products.json: All products in one file
# - analysis_summary.json: Statistics and insights
```

## File Structure

After deployment, each instance has:

```
/opt/ghost-protocol/
├── data/
│   ├── extracted/      # JSON files for each product
│   ├── raw_html/       # Downloaded HTML files
│   └── logs/           # Processing logs
├── urls_chunk.txt      # The 5000 URLs for this instance
├── instance_config.json # Instance metadata
└── docker-compose.yml  # Container configuration
```

## Scaling Guidelines

- **5000 URLs per instance**: Optimal for 2GB RAM instances
- **Processing time**: ~2-4 hours per chunk (depends on network)
- **Storage needed**: ~1-2GB per chunk (HTML + extracted data)
- **Recommended**: t3.small or t3.medium AWS instances

## Example: Process 1M URLs

For 1 million URLs with 5000 per chunk:
- Total chunks: 200
- With 10 instances: 20 chunks per instance
- Total time: ~40-80 hours (running in parallel)

## Troubleshooting

### Check deployment status
```bash
cat deployment_status_*.json
```

### Re-deploy failed chunk
```bash
./simple_deploy.sh 42 54.123.45.67  # Re-deploy chunk 42
```

### View container resource usage
```bash
ssh ubuntu@54.123.45.67 'docker stats --no-stream'
```

### Clean up instance
```bash
ssh ubuntu@54.123.45.67 'docker-compose down && sudo rm -rf /opt/ghost-protocol'
```

## Cost Optimization

1. Use spot instances for processing
2. Stop instances after collection
3. Transfer results to S3 for long-term storage
4. Use smallest instance type that handles 5000 URLs reliably

## Security Notes

- Always use SSH keys (never passwords)
- Keep instances in private subnet if possible
- Delete instances after collecting results
- Don't commit SSH keys or instance IPs to git