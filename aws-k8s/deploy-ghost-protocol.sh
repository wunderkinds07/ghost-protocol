#!/bin/bash
# Deploy Ghost Protocol to EKS cluster

set -e

REGION=${1:-us-east-1}
CHUNKS_DIR=${2:-../chunks}
MAX_PARALLEL_JOBS=${3:-20}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Deploying Ghost Protocol to $REGION ===${NC}"

# Check if chunks exist
if [ ! -d "$CHUNKS_DIR" ]; then
    echo -e "${RED}Chunks directory not found: $CHUNKS_DIR${NC}"
    echo "Please run: python3 prepare_chunks.py your-urls.txt 5000 chunks"
    exit 1
fi

# Get cluster info
if [ ! -f "cluster-info-$REGION.json" ]; then
    echo -e "${RED}Cluster info not found for region $REGION${NC}"
    echo "Please run: ./setup-eks-cluster.sh first"
    exit 1
fi

CLUSTER_NAME=$(cat cluster-info-$REGION.json | jq -r '.cluster_name')
ECR_URI=$(cat cluster-info-$REGION.json | jq -r '.ecr_uri')

# Get image URI
if [ ! -f "image-uri-$REGION.txt" ]; then
    echo -e "${RED}Image URI not found for region $REGION${NC}"
    echo "Please run: ./build-and-push-image.sh $REGION first"
    exit 1
fi

IMAGE_URI=$(cat image-uri-$REGION.txt)

echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Image: $IMAGE_URI"
echo "Max parallel jobs: $MAX_PARALLEL_JOBS"
echo ""

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f ../k8s/namespace.yaml

# Create ConfigMap
echo -e "${YELLOW}Creating ConfigMap...${NC}"
kubectl apply -f ../k8s/configmap.yaml

# Create ConfigMaps for each chunk
echo -e "${YELLOW}Creating URL ConfigMaps for chunks...${NC}"
CHUNK_COUNT=0
for chunk_file in $CHUNKS_DIR/urls_chunk_*.txt; do
    if [ -f "$chunk_file" ]; then
        # Extract chunk ID from filename
        CHUNK_ID=$(basename "$chunk_file" | sed 's/urls_chunk_//' | sed 's/.txt//')
        
        echo "  Creating ConfigMap for chunk $CHUNK_ID"
        
        # Create ConfigMap for this chunk
        kubectl create configmap ghost-protocol-urls-$CHUNK_ID \
            --from-file=urls_chunk_$CHUNK_ID.txt="$chunk_file" \
            --namespace=ghost-protocol \
            --dry-run=client -o yaml | kubectl apply -f -
        
        CHUNK_COUNT=$((CHUNK_COUNT + 1))
    fi
done

echo -e "${GREEN}✓ Created ConfigMaps for $CHUNK_COUNT chunks${NC}"

# Deploy jobs in batches
echo -e "${YELLOW}Deploying processing jobs...${NC}"
DEPLOYED_JOBS=0
BATCH_SIZE=5

for chunk_file in $CHUNKS_DIR/urls_chunk_*.txt; do
    if [ -f "$chunk_file" ]; then
        CHUNK_ID=$(basename "$chunk_file" | sed 's/urls_chunk_//' | sed 's/.txt//')
        
        # Create job manifest from template
        sed -e "s/CHUNK_ID/$CHUNK_ID/g" \
            -e "s/REGION/$REGION/g" \
            -e "s|ghost-protocol:latest|$IMAGE_URI|g" \
            ../k8s/job.yaml > /tmp/job-$CHUNK_ID.yaml
        
        # Apply job
        echo "  Deploying job for chunk $CHUNK_ID"
        kubectl apply -f /tmp/job-$CHUNK_ID.yaml
        
        DEPLOYED_JOBS=$((DEPLOYED_JOBS + 1))
        
        # Limit parallel jobs
        if [ $((DEPLOYED_JOBS % BATCH_SIZE)) -eq 0 ]; then
            echo "    Deployed $DEPLOYED_JOBS jobs, waiting a moment..."
            sleep 2
        fi
        
        # Stop if we hit the parallel limit
        if [ $DEPLOYED_JOBS -ge $MAX_PARALLEL_JOBS ]; then
            echo -e "${YELLOW}Reached max parallel jobs limit ($MAX_PARALLEL_JOBS)${NC}"
            echo "Deploy remaining chunks later or increase the limit"
            break
        fi
        
        # Cleanup temp file
        rm -f /tmp/job-$CHUNK_ID.yaml
    fi
done

echo -e "${GREEN}✓ Deployed $DEPLOYED_JOBS processing jobs${NC}"

# Create monitoring script
cat > monitor-jobs-$REGION.sh << 'EOF'
#!/bin/bash
# Monitor Ghost Protocol jobs

REGION=REGION_PLACEHOLDER

echo "=== Ghost Protocol Job Status ==="
echo "Region: $REGION"
echo ""

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $(cat cluster-info-$REGION.json | jq -r '.cluster_name') > /dev/null 2>&1

# Job status summary
echo "Job Summary:"
kubectl get jobs -n ghost-protocol --no-headers | awk '{
    if ($2 == "1/1") completed++
    else if ($3 > 0) running++
    else pending++
    total++
}
END {
    print "  Total: " total
    print "  Completed: " completed
    print "  Running: " running  
    print "  Pending: " pending
}'

echo ""
echo "Recent job status:"
kubectl get jobs -n ghost-protocol | head -10

echo ""
echo "Failed jobs:"
kubectl get jobs -n ghost-protocol --field-selector status.successful!=1 | grep -v "0/1" || echo "  No failed jobs"

echo ""
echo "Running pods:"
kubectl get pods -n ghost-protocol --field-selector status.phase=Running | head -5

echo ""
echo "To check logs: kubectl logs -n ghost-protocol <pod-name>"
echo "To get results: ./collect-results-k8s.sh $REGION"
EOF

# Replace placeholder and make executable
sed -i "s/REGION_PLACEHOLDER/$REGION/g" monitor-jobs-$REGION.sh
chmod +x monitor-jobs-$REGION.sh

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo "Deployed: $DEPLOYED_JOBS jobs"
echo "Monitor progress: ./monitor-jobs-$REGION.sh"
echo "Collect results: ./collect-results-k8s.sh $REGION"
echo ""
echo "Useful commands:"
echo "  kubectl get jobs -n ghost-protocol"
echo "  kubectl get pods -n ghost-protocol"
echo "  kubectl logs -n ghost-protocol <pod-name>"