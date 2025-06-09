#!/bin/bash
# Collect results from all deployed instances

set -e

# Configuration
INSTANCE_IPS_FILE=${1:-instances.txt}
SSH_KEY=${2:-~/.ssh/id_rsa}
REMOTE_USER=${3:-ubuntu}
OUTPUT_DIR=${4:-collected_results_$(date +%Y%m%d_%H%M%S)}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage
if [ ! -f "$INSTANCE_IPS_FILE" ]; then
    echo "Usage: $0 <instances_file> [ssh_key] [remote_user] [output_dir]"
    echo "Example: $0 instances.txt ~/.ssh/my-key.pem ubuntu results"
    exit 1
fi

# Read instances
readarray -t INSTANCES < "$INSTANCE_IPS_FILE"

echo -e "${BLUE}=== Collecting Results from Instances ===${NC}"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p $OUTPUT_DIR

# Create collection summary
SUMMARY_FILE="$OUTPUT_DIR/collection_summary.json"
echo "{" > $SUMMARY_FILE
echo "  \"collection_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> $SUMMARY_FILE
echo "  \"instances\": [" >> $SUMMARY_FILE

FIRST=true

# Collect from each instance
for INSTANCE_IP in "${INSTANCES[@]}"; do
    echo -e "${YELLOW}Collecting from $INSTANCE_IP...${NC}"
    
    # Create instance directory
    INSTANCE_DIR="$OUTPUT_DIR/instance_${INSTANCE_IP//./_}"
    mkdir -p $INSTANCE_DIR
    
    # Get container names on this instance
    CONTAINERS=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_USER@$INSTANCE_IP \
        'docker ps --format "{{.Names}}" | grep ghost-chunk || true')
    
    if [ -z "$CONTAINERS" ]; then
        echo "  No ghost-chunk containers found on $INSTANCE_IP"
        continue
    fi
    
    # Add to summary
    if [ "$FIRST" = false ]; then
        echo "," >> $SUMMARY_FILE
    fi
    FIRST=false
    
    echo -n "    {" >> $SUMMARY_FILE
    echo -n "\"instance_ip\": \"$INSTANCE_IP\", " >> $SUMMARY_FILE
    echo -n "\"containers\": [" >> $SUMMARY_FILE
    
    FIRST_CONTAINER=true
    
    # Process each container
    for CONTAINER in $CONTAINERS; do
        echo "  Found container: $CONTAINER"
        
        # Extract chunk ID from container name
        CHUNK_ID=$(echo $CONTAINER | sed 's/ghost-chunk-//')
        
        # Create chunk directory
        CHUNK_DIR="$INSTANCE_DIR/chunk_$CHUNK_ID"
        mkdir -p $CHUNK_DIR
        
        # Copy data
        echo "  Copying data from $CONTAINER..."
        scp -i $SSH_KEY -r -o StrictHostKeyChecking=no \
            $REMOTE_USER@$INSTANCE_IP:/opt/ghost-protocol/data/* \
            $CHUNK_DIR/ 2>/dev/null || true
        
        # Get container logs
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_USER@$INSTANCE_IP \
            "docker logs $CONTAINER > /tmp/${CONTAINER}.log 2>&1"
        
        scp -i $SSH_KEY -o StrictHostKeyChecking=no \
            $REMOTE_USER@$INSTANCE_IP:/tmp/${CONTAINER}.log \
            $CHUNK_DIR/container.log
        
        # Add to summary
        if [ "$FIRST_CONTAINER" = false ]; then
            echo -n ", " >> $SUMMARY_FILE
        fi
        FIRST_CONTAINER=false
        
        echo -n "\"$CONTAINER\"" >> $SUMMARY_FILE
        
        echo -e "  ${GREEN}✓ Collected data for chunk $CHUNK_ID${NC}"
    done
    
    echo -n "], " >> $SUMMARY_FILE
    echo -n "\"status\": \"collected\"}" >> $SUMMARY_FILE
done

echo "" >> $SUMMARY_FILE
echo "  ]" >> $SUMMARY_FILE
echo "}" >> $SUMMARY_FILE

# Create aggregated results
echo -e "${YELLOW}Aggregating results...${NC}"

# Count total files collected
TOTAL_EXTRACTED=$(find $OUTPUT_DIR -name "*.json" -path "*/extracted/*" | wc -l)
TOTAL_HTML=$(find $OUTPUT_DIR -name "*.html" -path "*/raw_html/*" | wc -l)

echo -e "${GREEN}=== Collection Complete ===${NC}"
echo "Results saved to: $OUTPUT_DIR"
echo "Total extracted products: $TOTAL_EXTRACTED"
echo "Total HTML files: $TOTAL_HTML"
echo "Collection summary: $SUMMARY_FILE"
echo ""
echo "To merge all extracted data:"
echo "  python merge_extracted_data.py $OUTPUT_DIR"