#!/bin/bash
# Deploy Ghost Protocol across multiple AWS regions

set -e

# Configuration
REGIONS=${1:-"us-east-1,us-west-2,eu-west-1"}
CHUNKS_PER_REGION=${2:-50}
CLUSTER_NAME=${3:-ghost-protocol}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Ghost Protocol Multi-Region Deployment ===${NC}"
echo "Regions: $REGIONS"
echo "Chunks per region: $CHUNKS_PER_REGION"
echo "Cluster name: $CLUSTER_NAME"
echo ""

# Convert comma-separated regions to array
IFS=',' read -ra REGION_ARRAY <<< "$REGIONS"

# Check prerequisites
if [ ! -d "../chunks" ]; then
    echo -e "${RED}Chunks directory not found. Please run:${NC}"
    echo "python3 prepare_chunks.py your-urls.txt 5000 chunks"
    exit 1
fi

TOTAL_CHUNKS=$(ls ../chunks/urls_chunk_*.txt 2>/dev/null | wc -l)
if [ $TOTAL_CHUNKS -eq 0 ]; then
    echo -e "${RED}No chunk files found in ../chunks/${NC}"
    exit 1
fi

echo "Total chunks available: $TOTAL_CHUNKS"
echo "Regions to deploy: ${#REGION_ARRAY[@]}"
echo ""

# Calculate chunk distribution
CHUNKS_PER_REGION_ACTUAL=$(( (TOTAL_CHUNKS + ${#REGION_ARRAY[@]} - 1) / ${#REGION_ARRAY[@]} ))
if [ $CHUNKS_PER_REGION -gt 0 ] && [ $CHUNKS_PER_REGION -lt $CHUNKS_PER_REGION_ACTUAL ]; then
    CHUNKS_PER_REGION_ACTUAL=$CHUNKS_PER_REGION
fi

echo "Chunks per region (calculated): $CHUNKS_PER_REGION_ACTUAL"
echo ""

# Create deployment plan
echo -e "${YELLOW}Creating deployment plan...${NC}"
CHUNK_INDEX=1
DEPLOYMENT_PLAN="deployment-plan-$(date +%Y%m%d_%H%M%S).json"

cat > $DEPLOYMENT_PLAN << EOF
{
  "deployment_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_chunks": $TOTAL_CHUNKS,
  "regions": [
EOF

FIRST_REGION=true
for REGION in "${REGION_ARRAY[@]}"; do
    if [ "$FIRST_REGION" = false ]; then
        echo "," >> $DEPLOYMENT_PLAN
    fi
    FIRST_REGION=false
    
    # Calculate chunk range for this region
    START_CHUNK=$CHUNK_INDEX
    END_CHUNK=$(( CHUNK_INDEX + CHUNKS_PER_REGION_ACTUAL - 1 ))
    if [ $END_CHUNK -gt $TOTAL_CHUNKS ]; then
        END_CHUNK=$TOTAL_CHUNKS
    fi
    
    REGION_CHUNKS=$(( END_CHUNK - START_CHUNK + 1 ))
    
    cat >> $DEPLOYMENT_PLAN << EOF
    {
      "region": "$REGION",
      "chunk_start": $START_CHUNK,
      "chunk_end": $END_CHUNK,
      "chunk_count": $REGION_CHUNKS,
      "cluster_name": "$CLUSTER_NAME"
    }
EOF
    
    CHUNK_INDEX=$(( END_CHUNK + 1 ))
    
    echo "  $REGION: chunks $START_CHUNK-$END_CHUNK ($REGION_CHUNKS chunks)"
    
    # Stop if we've assigned all chunks
    if [ $CHUNK_INDEX -gt $TOTAL_CHUNKS ]; then
        break
    fi
done

cat >> $DEPLOYMENT_PLAN << EOF

  ]
}
EOF

echo ""
echo "Deployment plan saved to: $DEPLOYMENT_PLAN"
echo ""

# Deploy to each region
echo -e "${YELLOW}Starting multi-region deployment...${NC}"

for REGION in "${REGION_ARRAY[@]}"; do
    echo -e "${BLUE}=== Deploying to $REGION ===${NC}"
    
    # Get region info from deployment plan
    REGION_INFO=$(cat $DEPLOYMENT_PLAN | jq -r ".regions[] | select(.region == \"$REGION\")")
    CHUNK_START=$(echo "$REGION_INFO" | jq -r '.chunk_start')
    CHUNK_END=$(echo "$REGION_INFO" | jq -r '.chunk_end')
    CHUNK_COUNT=$(echo "$REGION_INFO" | jq -r '.chunk_count')
    
    if [ "$CHUNK_START" = "null" ]; then
        echo "  No chunks assigned to $REGION, skipping..."
        continue
    fi
    
    echo "  Setting up EKS cluster..."
    if ! ./setup-eks-cluster.sh $CLUSTER_NAME $REGION t3.medium 1 20; then
        echo -e "${RED}  Failed to setup cluster in $REGION${NC}"
        continue
    fi
    
    echo "  Building and pushing image..."
    if ! ./build-and-push-image.sh $REGION; then
        echo -e "${RED}  Failed to build/push image in $REGION${NC}"
        continue
    fi
    
    # Create region-specific chunks directory
    REGION_CHUNKS_DIR="../chunks-$REGION"
    mkdir -p $REGION_CHUNKS_DIR
    
    # Copy assigned chunks to region-specific directory
    echo "  Copying chunks $CHUNK_START-$CHUNK_END to region directory..."
    for ((i=$CHUNK_START; i<=$CHUNK_END; i++)); do
        CHUNK_FILE=$(printf "../chunks/urls_chunk_%04d.txt" $i)
        if [ -f "$CHUNK_FILE" ]; then
            cp "$CHUNK_FILE" "$REGION_CHUNKS_DIR/"
        fi
    done
    
    echo "  Deploying Ghost Protocol jobs..."
    if ! ./deploy-ghost-protocol.sh $REGION $REGION_CHUNKS_DIR $CHUNK_COUNT; then
        echo -e "${RED}  Failed to deploy jobs in $REGION${NC}"
        continue
    fi
    
    echo -e "${GREEN}  ✓ Successfully deployed to $REGION ($CHUNK_COUNT chunks)${NC}"
    echo ""
done

# Create global monitoring script
cat > monitor-all-regions.sh << 'EOFMON'
#!/bin/bash
# Monitor Ghost Protocol across all regions

DEPLOYMENT_PLAN_FILE=""
for file in deployment-plan-*.json; do
    if [ -f "$file" ]; then
        DEPLOYMENT_PLAN_FILE="$file"
        break
    fi
done

if [ -z "$DEPLOYMENT_PLAN_FILE" ]; then
    echo "No deployment plan found"
    exit 1
fi

echo "=== Ghost Protocol Multi-Region Status ==="
echo "Plan: $DEPLOYMENT_PLAN_FILE"
echo ""

TOTAL_JOBS=0
TOTAL_COMPLETED=0
TOTAL_RUNNING=0
TOTAL_FAILED=0

# Get regions from deployment plan
REGIONS=$(cat "$DEPLOYMENT_PLAN_FILE" | jq -r '.regions[].region')

for REGION in $REGIONS; do
    echo "Region: $REGION"
    
    # Update kubeconfig for this region
    CLUSTER_NAME=$(cat cluster-info-$REGION.json 2>/dev/null | jq -r '.cluster_name' 2>/dev/null || echo "ghost-protocol")
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME > /dev/null 2>&1
    
    # Get job stats
    JOB_STATS=$(kubectl get jobs -n ghost-protocol --no-headers 2>/dev/null | awk '{
        if ($2 == "1/1") completed++
        else if ($3 > 0) running++
        else failed++
        total++
    }
    END {
        print total " " completed " " running " " failed
    }') || JOB_STATS="0 0 0 0"
    
    read JOBS COMPLETED RUNNING FAILED <<< "$JOB_STATS"
    
    echo "  Jobs: $JOBS, Completed: $COMPLETED, Running: $RUNNING, Failed: $FAILED"
    
    TOTAL_JOBS=$((TOTAL_JOBS + JOBS))
    TOTAL_COMPLETED=$((TOTAL_COMPLETED + COMPLETED))
    TOTAL_RUNNING=$((TOTAL_RUNNING + RUNNING))
    TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
    
    echo ""
done

echo "=== Global Summary ==="
echo "Total Jobs: $TOTAL_JOBS"
echo "Completed: $TOTAL_COMPLETED"
echo "Running: $TOTAL_RUNNING"
echo "Failed: $TOTAL_FAILED"

if [ $TOTAL_JOBS -gt 0 ]; then
    COMPLETION_PERCENT=$(( TOTAL_COMPLETED * 100 / TOTAL_JOBS ))
    echo "Completion: $COMPLETION_PERCENT%"
fi

echo ""
echo "Monitor individual regions:"
for REGION in $REGIONS; do
    if [ -f "monitor-jobs-$REGION.sh" ]; then
        echo "  ./monitor-jobs-$REGION.sh"
    fi
done
EOFMON

chmod +x monitor-all-regions.sh

# Create results collection script
cat > collect-all-results.sh << 'EOFCOL'
#!/bin/bash
# Collect results from all regions

DEPLOYMENT_PLAN_FILE=""
for file in deployment-plan-*.json; do
    if [ -f "$file" ]; then
        DEPLOYMENT_PLAN_FILE="$file"
        break
    fi
done

if [ -z "$DEPLOYMENT_PLAN_FILE" ]; then
    echo "No deployment plan found"
    exit 1
fi

OUTPUT_DIR="multi-region-results-$(date +%Y%m%d_%H%M%S)"
mkdir -p $OUTPUT_DIR

echo "=== Collecting Results from All Regions ==="
echo "Output directory: $OUTPUT_DIR"
echo ""

# Get regions from deployment plan
REGIONS=$(cat "$DEPLOYMENT_PLAN_FILE" | jq -r '.regions[].region')

for REGION in $REGIONS; do
    echo "Collecting from $REGION..."
    
    if [ -f "collect-results-k8s.sh" ]; then
        ./collect-results-k8s.sh $REGION $OUTPUT_DIR/$REGION || echo "  Failed to collect from $REGION"
    else
        echo "  collect-results-k8s.sh not found"
    fi
done

echo ""
echo "Merging all results..."
if [ -f "../merge_extracted_data.py" ]; then
    cd .. && python3 merge_extracted_data.py aws-k8s/$OUTPUT_DIR
    cd aws-k8s
    echo "Merged results saved to: ../merged_products.json"
else
    echo "merge_extracted_data.py not found"
fi

echo ""
echo "Results collection complete!"
echo "Directory: $OUTPUT_DIR"
EOFCOL

chmod +x collect-all-results.sh

echo -e "${GREEN}=== Multi-Region Deployment Complete ===${NC}"
echo ""
echo "Deployment plan: $DEPLOYMENT_PLAN"
echo "Monitor progress: ./monitor-all-regions.sh"
echo "Collect results: ./collect-all-results.sh"
echo ""
echo "Individual region monitoring:"
for REGION in "${REGION_ARRAY[@]}"; do
    if [ -f "monitor-jobs-$REGION.sh" ]; then
        echo "  $REGION: ./monitor-jobs-$REGION.sh"
    fi
done