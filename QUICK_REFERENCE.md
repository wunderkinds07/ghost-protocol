# 1stDibs Extractor - Quick Reference 🚀

## What This Does
Extracts product data from 1stDibs URLs using Docker containers with creative names (phoenix, gallardo, nebula, etc.)

## Key Numbers
- **5,000** URLs per container
- **60-80** URLs processed per minute
- **95-99%** success rate
- **200KB** storage per product (compressed)
- **250+** creative container names

## Project Structure
```
battlefield/
├── src/                    # Core extraction logic
├── docker/                 # Container configuration
├── deployment/             # Deployment scripts
├── data/                   # Output data
└── *.md                    # Documentation files
```

## Notifications

All containers automatically send notifications to:
**https://ntfy.sh/callofdutyblackopsghostprotocolbravo64**

Monitor progress in real-time - no setup needed!

## Essential Commands

### 1. Test Locally (3 URLs)
```bash
./test_local.sh
```

### 2. Full Deployment
```bash
# Step 1: Prepare URL chunks
python deployment/prepare_chunks.py urls.txt 5000

# Step 2: Build Docker images
./deployment/build_images.sh

# Step 3: Deploy all containers
docker-compose -f deployment/docker-compose.yml up -d

# Step 4: Monitor progress
docker logs -f 1stdibs-phoenix
```

### 3. Check Results
```bash
# Count extracted products
find data/*/extracted -name "*.json" | wc -l

# View container summary
cat data/phoenix/container_phoenix_summary.json

# Check errors
grep ERROR data/*/logs/extraction.log
```

## Data Output

Each product creates two files:
1. **Raw HTML**: `data/phoenix/raw_html/f_12345.html.gz`
2. **JSON Data**: `data/phoenix/extracted/f_12345.json`

## Container Names
Instead of boring numbers (container-1, container-2), we use creative names:
- Military: alpha, bravo, charlie
- Space: apollo, cosmos, nebula
- Mythology: phoenix, dragon, kraken
- Nature: eagle, tiger, cobra
- Gems: diamond, ruby, sapphire
- Cars: gallardo, aventador, huracan

## Scaling
- **Local**: Run multiple docker-compose services
- **Cloud**: Deploy to ECS, GKE, or AKS
- **Performance**: Add more containers for linear scaling

## Troubleshooting
```bash
# Verify setup
./verify_deployment.sh

# Check container health
docker ps -a | grep 1stdibs

# View logs
docker logs 1stdibs-phoenix --tail 50

# Restart failed container
docker restart 1stdibs-phoenix
```

## Documentation
- **Quick Start**: PROJECT_SUMMARY.md
- **Full Details**: DETAILED_PROJECT_DOCUMENTATION.md
- **Technical Specs**: TECHNICAL_SPECIFICATION.md
- **This Guide**: QUICK_REFERENCE.md