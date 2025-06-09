#!/bin/bash
# Deploy multiple instances with automatic chunk assignment
# Each instance processes one chunk of 5000 URLs

set -e

# Configuration
INSTANCE_IPS_FILE=${1:-instances.txt}
SSH_KEY=${2:-~/.ssh/id_rsa}
REMOTE_USER=${3:-ubuntu}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage
if [ ! -f "$INSTANCE_IPS_FILE" ]; then
    echo "Usage: $0 <instances_file> [ssh_key] [remote_user]"
    echo ""
    echo "Create an instances.txt file with one IP address per line:"
    echo "  54.123.45.67"
    echo "  54.123.45.68"
    echo "  54.123.45.69"
    echo ""
    echo "Example: $0 instances.txt ~/.ssh/my-key.pem ubuntu"
    exit 1
fi

# Check chunks exist
if [ ! -d "chunks" ] || [ ! -f "chunks/chunks_manifest.json" ]; then
    echo -e "${RED}Error: No chunks found. Run 'python prepare_chunks.py' first${NC}"
    exit 1
fi

# Read instance IPs
readarray -t INSTANCES < "$INSTANCE_IPS_FILE"
NUM_INSTANCES=${#INSTANCES[@]}

# Get chunk info
NUM_CHUNKS=$(ls chunks/urls_chunk_*.txt 2>/dev/null | wc -l)

echo -e "${BLUE}=== Ghost Protocol Multi-Instance Deploy ===${NC}"
echo "Instances available: $NUM_INSTANCES"
echo "Chunks to process: $NUM_CHUNKS"
echo "SSH Key: $SSH_KEY"
echo "Remote user: $REMOTE_USER"
echo ""

if [ $NUM_CHUNKS -eq 0 ]; then
    echo -e "${RED}No chunks found!${NC}"
    exit 1
fi

if [ $NUM_INSTANCES -eq 0 ]; then
    echo -e "${RED}No instances found in $INSTANCE_IPS_FILE${NC}"
    exit 1
fi

# Calculate chunks per instance
CHUNKS_PER_INSTANCE=$(( (NUM_CHUNKS + NUM_INSTANCES - 1) / NUM_INSTANCES ))

echo "Chunks per instance: ~$CHUNKS_PER_INSTANCE"
echo ""

# Create deployment status file
DEPLOY_STATUS="deployment_status_$(date +%Y%m%d_%H%M%S).json"
echo "{" > $DEPLOY_STATUS
echo "  \"deployment_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> $DEPLOY_STATUS
echo "  \"total_chunks\": $NUM_CHUNKS," >> $DEPLOY_STATUS
echo "  \"total_instances\": $NUM_INSTANCES," >> $DEPLOY_STATUS
echo "  \"deployments\": [" >> $DEPLOY_STATUS

# Deploy chunks to instances
CHUNK_ID=1
INSTANCE_INDEX=0
DEPLOY_COUNT=0

for ((CHUNK_ID=1; CHUNK_ID<=NUM_CHUNKS; CHUNK_ID++)); do
    # Get instance for this chunk
    INSTANCE_IP=${INSTANCES[$INSTANCE_INDEX]}
    
    echo -e "${YELLOW}Deploying chunk $CHUNK_ID/$NUM_CHUNKS to $INSTANCE_IP${NC}"
    
    # Deploy chunk
    if bash simple_deploy.sh $CHUNK_ID $INSTANCE_IP $SSH_KEY $REMOTE_USER; then
        echo -e "${GREEN}✓ Successfully deployed chunk $CHUNK_ID to $INSTANCE_IP${NC}"
        
        # Add to status file
        if [ $DEPLOY_COUNT -gt 0 ]; then
            echo "," >> $DEPLOY_STATUS
        fi
        echo -n "    {\"chunk_id\": $CHUNK_ID, \"instance_ip\": \"$INSTANCE_IP\", \"status\": \"deployed\"}" >> $DEPLOY_STATUS
        DEPLOY_COUNT=$((DEPLOY_COUNT + 1))
    else
        echo -e "${RED}✗ Failed to deploy chunk $CHUNK_ID to $INSTANCE_IP${NC}"
        
        # Add failure to status file
        if [ $DEPLOY_COUNT -gt 0 ]; then
            echo "," >> $DEPLOY_STATUS
        fi
        echo -n "    {\"chunk_id\": $CHUNK_ID, \"instance_ip\": \"$INSTANCE_IP\", \"status\": \"failed\"}" >> $DEPLOY_STATUS
        DEPLOY_COUNT=$((DEPLOY_COUNT + 1))
    fi
    
    # Move to next instance (round-robin)
    INSTANCE_INDEX=$(( (INSTANCE_INDEX + 1) % NUM_INSTANCES ))
    
    echo ""
done

# Close deployment status file
echo "" >> $DEPLOY_STATUS
echo "  ]" >> $DEPLOY_STATUS
echo "}" >> $DEPLOY_STATUS

echo -e "${GREEN}=== Deployment Summary ===${NC}"
echo "Deployment status saved to: $DEPLOY_STATUS"
echo ""
echo "Monitor all instances:"
for INSTANCE_IP in "${INSTANCES[@]}"; do
    echo "  ssh -i $SSH_KEY $REMOTE_USER@$INSTANCE_IP 'docker ps'"
done
echo ""
echo "Collect all results later:"
echo "  bash collect_results.sh $INSTANCE_IPS_FILE $SSH_KEY $REMOTE_USER"