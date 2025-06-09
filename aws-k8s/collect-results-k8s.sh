#!/bin/bash
# Collect results from Kubernetes Ghost Protocol jobs

set -e

REGION=${1:-us-east-1}
OUTPUT_DIR=${2:-results-k8s-$(date +%Y%m%d_%H%M%S)}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Collecting Results from $REGION ===${NC}"

# Get cluster info
if [ ! -f "cluster-info-$REGION.json" ]; then
    echo "Cluster info not found for region $REGION"
    exit 1
fi

CLUSTER_NAME=$(cat cluster-info-$REGION.json | jq -r '.cluster_name')

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Create output directory
mkdir -p $OUTPUT_DIR

echo "Output directory: $OUTPUT_DIR"
echo ""

# Get all completed pods
echo -e "${YELLOW}Finding completed jobs...${NC}"
COMPLETED_JOBS=$(kubectl get jobs -n ghost-protocol --no-headers | awk '$2 == "1/1" {print $1}')

if [ -z "$COMPLETED_JOBS" ]; then
    echo "No completed jobs found"
    exit 0
fi

JOB_COUNT=$(echo "$COMPLETED_JOBS" | wc -l)
echo "Found $JOB_COUNT completed jobs"
echo ""

# Collect results from each completed job
COLLECTED=0
for JOB_NAME in $COMPLETED_JOBS; do
    echo -e "${YELLOW}Collecting from job: $JOB_NAME${NC}"
    
    # Get pod name for this job
    POD_NAME=$(kubectl get pods -n ghost-protocol --selector=job-name=$JOB_NAME --no-headers | awk '{print $1}' | head -1)
    
    if [ -z "$POD_NAME" ]; then
        echo "  No pod found for job $JOB_NAME"
        continue
    fi
    
    # Create job output directory
    JOB_OUTPUT_DIR="$OUTPUT_DIR/$JOB_NAME"
    mkdir -p $JOB_OUTPUT_DIR
    
    # Copy files from pod
    echo "  Copying extracted data..."
    kubectl cp ghost-protocol/$POD_NAME:/app/data/output/ $JOB_OUTPUT_DIR/ || echo "    Failed to copy extracted data"
    
    echo "  Copying logs..."
    kubectl logs -n ghost-protocol $POD_NAME > $JOB_OUTPUT_DIR/pod.log || echo "    Failed to copy logs"
    
    # Get job info
    kubectl get job -n ghost-protocol $JOB_NAME -o yaml > $JOB_OUTPUT_DIR/job-info.yaml
    kubectl get pod -n ghost-protocol $POD_NAME -o yaml > $JOB_OUTPUT_DIR/pod-info.yaml
    
    COLLECTED=$((COLLECTED + 1))
    echo "  ✓ Collected data for $JOB_NAME"
done

# Create collection summary
cat > $OUTPUT_DIR/collection-summary.json << EOF
{
  "region": "$REGION",
  "cluster_name": "$CLUSTER_NAME",
  "collection_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_jobs_found": $JOB_COUNT,
  "jobs_collected": $COLLECTED,
  "output_directory": "$OUTPUT_DIR"
}
EOF

# Count collected files
EXTRACTED_FILES=$(find $OUTPUT_DIR -name "*.json" -path "*/extracted/*" 2>/dev/null | wc -l)
HTML_FILES=$(find $OUTPUT_DIR -name "*.html*" -path "*/raw_html/*" 2>/dev/null | wc -l)

echo -e "${GREEN}=== Collection Complete ===${NC}"
echo "Region: $REGION"
echo "Jobs collected: $COLLECTED"
echo "Extracted files: $EXTRACTED_FILES"
echo "HTML files: $HTML_FILES"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "To merge data:"
echo "  python3 ../merge_extracted_data.py $OUTPUT_DIR"