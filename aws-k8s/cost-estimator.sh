#!/bin/bash
# Cost estimator for Ghost Protocol AWS+Kubernetes deployment

set -e

# Configuration
TOTAL_URLS=${1:-1000000}
REGIONS=${2:-"us-east-1,us-west-2,eu-west-1"}
INSTANCE_TYPE=${3:-t3.medium}
USE_SPOT=${4:-false}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Ghost Protocol Cost Estimator ===${NC}"
echo "Total URLs: $(printf "%'d" $TOTAL_URLS)"
echo "Regions: $REGIONS"
echo "Instance type: $INSTANCE_TYPE"
echo "Use spot instances: $USE_SPOT"
echo ""

# Convert regions to array
IFS=',' read -ra REGION_ARRAY <<< "$REGIONS"
NUM_REGIONS=${#REGION_ARRAY[@]}

# Calculate chunks and distribution
CHUNK_SIZE=5000
TOTAL_CHUNKS=$(( (TOTAL_URLS + CHUNK_SIZE - 1) / CHUNK_SIZE ))
CHUNKS_PER_REGION=$(( (TOTAL_CHUNKS + NUM_REGIONS - 1) / NUM_REGIONS ))

echo -e "${YELLOW}Processing Overview:${NC}"
echo "  URLs per chunk: $(printf "%'d" $CHUNK_SIZE)"
echo "  Total chunks: $(printf "%'d" $TOTAL_CHUNKS)"
echo "  Regions: $NUM_REGIONS"
echo "  Chunks per region: $(printf "%'d" $CHUNKS_PER_REGION)"
echo ""

# Instance pricing (per hour, approximate US East prices)
case $INSTANCE_TYPE in
    "t3.small")
        HOURLY_COST=0.0208
        PODS_PER_NODE=3
        ;;
    "t3.medium")
        HOURLY_COST=0.0416
        PODS_PER_NODE=5
        ;;
    "t3.large")
        HOURLY_COST=0.0832
        PODS_PER_NODE=10
        ;;
    "t3.xlarge")
        HOURLY_COST=0.1664
        PODS_PER_NODE=20
        ;;
    *)
        HOURLY_COST=0.0416
        PODS_PER_NODE=5
        ;;
esac

# Apply spot discount
if [ "$USE_SPOT" = "true" ]; then
    HOURLY_COST=$(echo "$HOURLY_COST * 0.3" | bc -l)  # ~70% discount
    SPOT_LABEL=" (spot)"
else
    SPOT_LABEL=""
fi

# Processing time estimation
URLS_PER_HOUR=1000  # Conservative estimate
HOURS_PER_CHUNK=$(echo "scale=2; $CHUNK_SIZE / $URLS_PER_HOUR" | bc -l)
TOTAL_PROCESSING_HOURS=$(echo "scale=2; $CHUNKS_PER_REGION * $HOURS_PER_CHUNK" | bc -l)

# Calculate required nodes
NODES_PER_REGION=$(echo "scale=0; ($CHUNKS_PER_REGION + $PODS_PER_NODE - 1) / $PODS_PER_NODE" | bc -l)

echo -e "${YELLOW}Resource Requirements:${NC}"
echo "  Processing time per chunk: ${HOURS_PER_CHUNK}h"
echo "  Total processing time per region: ${TOTAL_PROCESSING_HOURS}h"
echo "  Pods per node ($INSTANCE_TYPE): $PODS_PER_NODE"
echo "  Nodes needed per region: $NODES_PER_REGION"
echo "  Total nodes across regions: $(echo "$NODES_PER_REGION * $NUM_REGIONS" | bc)"
echo ""

# Cost calculations
EKS_CLUSTER_COST=0.10  # $0.10/hour per cluster
EKS_MONTHLY_COST=$(echo "$EKS_CLUSTER_COST * 24 * 30" | bc -l)

# Worker node costs
NODE_COST_PER_REGION=$(echo "$NODES_PER_REGION * $HOURLY_COST * $TOTAL_PROCESSING_HOURS" | bc -l)
TOTAL_NODE_COST=$(echo "$NODE_COST_PER_REGION * $NUM_REGIONS" | bc -l)

# EKS cluster costs (only for processing duration)
EKS_PROCESSING_COST=$(echo "$EKS_CLUSTER_COST * $TOTAL_PROCESSING_HOURS * $NUM_REGIONS" | bc -l)

# Additional costs
ECR_COST=5.00      # Approximate for storing Docker images
DATA_TRANSFER=10.00 # Approximate for data transfer between regions
S3_STORAGE=20.00   # Approximate for storing results

TOTAL_PROCESSING_COST=$(echo "$TOTAL_NODE_COST + $EKS_PROCESSING_COST + $ECR_COST + $DATA_TRANSFER + $S3_STORAGE" | bc -l)

echo -e "${GREEN}=== Cost Breakdown ===${NC}"
echo ""
echo "Infrastructure Costs:"
printf "  EKS clusters (%d regions × %.1fh): \$%.2f\n" $NUM_REGIONS $TOTAL_PROCESSING_HOURS $EKS_PROCESSING_COST
printf "  Worker nodes (%s%s): \$%.2f\n" $INSTANCE_TYPE "$SPOT_LABEL" $TOTAL_NODE_COST
echo "  ECR image storage: \$$(printf "%.2f" $ECR_COST)"
echo "  Data transfer: \$$(printf "%.2f" $DATA_TRANSFER)"
echo "  S3 storage (results): \$$(printf "%.2f" $S3_STORAGE)"
echo "  ────────────────────────────"
printf "  Total Processing Cost: \$%.2f\n" $TOTAL_PROCESSING_COST
echo ""

# Monthly costs (if clusters kept running)
MONTHLY_NODE_COST=$(echo "$NODES_PER_REGION * $HOURLY_COST * 24 * 30 * $NUM_REGIONS" | bc -l)
MONTHLY_EKS_COST=$(echo "$EKS_CLUSTER_COST * 24 * 30 * $NUM_REGIONS" | bc -l)
TOTAL_MONTHLY_COST=$(echo "$MONTHLY_NODE_COST + $MONTHLY_EKS_COST" | bc -l)

echo "Monthly Costs (if clusters kept running):"
printf "  EKS clusters: \$%.2f/month\n" $MONTHLY_EKS_COST
printf "  Worker nodes: \$%.2f/month\n" $MONTHLY_NODE_COST
echo "  ────────────────────────────"
printf "  Total Monthly: \$%.2f/month\n" $TOTAL_MONTHLY_COST
echo ""

# Performance metrics
TOTAL_PROCESSING_TIME_PARALLEL=$TOTAL_PROCESSING_HOURS
TOTAL_PROCESSING_TIME_SINGLE=$(echo "$TOTAL_CHUNKS * $HOURS_PER_CHUNK" | bc -l)
TIME_SAVINGS=$(echo "$TOTAL_PROCESSING_TIME_SINGLE - $TOTAL_PROCESSING_TIME_PARALLEL" | bc -l)
SPEEDUP=$(echo "scale=1; $TOTAL_PROCESSING_TIME_SINGLE / $TOTAL_PROCESSING_TIME_PARALLEL" | bc -l)

echo -e "${YELLOW}Performance Comparison:${NC}"
printf "  Single region processing: %.1fh (%.1f days)\n" $TOTAL_PROCESSING_TIME_SINGLE $(echo "$TOTAL_PROCESSING_TIME_SINGLE / 24" | bc -l)
printf "  Multi-region processing: %.1fh (%.1f days)\n" $TOTAL_PROCESSING_TIME_PARALLEL $(echo "$TOTAL_PROCESSING_TIME_PARALLEL / 24" | bc -l)
printf "  Time savings: %.1fh (%.1fx speedup)\n" $TIME_SAVINGS $SPEEDUP
echo ""

# Cost per URL
COST_PER_URL=$(echo "scale=6; $TOTAL_PROCESSING_COST / $TOTAL_URLS" | bc -l)
COST_PER_1000_URLS=$(echo "$COST_PER_URL * 1000" | bc -l)

echo -e "${GREEN}Cost Efficiency:${NC}"
printf "  Cost per URL: \$%.6f\n" $COST_PER_URL
printf "  Cost per 1,000 URLs: \$%.3f\n" $COST_PER_1000_URLS
echo ""

# Optimization recommendations
echo -e "${YELLOW}Cost Optimization Tips:${NC}"
if [ "$USE_SPOT" = "false" ]; then
    SPOT_SAVINGS=$(echo "scale=2; $TOTAL_NODE_COST * 0.7" | bc -l)
    echo "  • Use spot instances: Save ~\$$(printf "%.2f" $SPOT_SAVINGS) (70% discount)"
fi

if [ $NUM_REGIONS -eq 1 ]; then
    echo "  • Add more regions: Faster completion, better availability"
else
    echo "  • Consider fewer regions: Lower EKS cluster costs"
fi

echo "  • Delete clusters immediately after processing"
echo "  • Use smaller instances for testing: t3.small costs \$$(echo "0.0208 * $NODES_PER_REGION * $TOTAL_PROCESSING_HOURS * $NUM_REGIONS" | bc -l | xargs printf "%.2f")"
echo "  • Process in batches: Spread costs over time"
echo ""

# Sample commands
echo -e "${BLUE}Sample Deployment Commands:${NC}"
echo "# Deploy with current settings:"
echo "./deploy-multi-region.sh \"$REGIONS\" $CHUNKS_PER_REGION"
echo ""
if [ "$USE_SPOT" = "true" ]; then
    echo "# Setup with spot instances:"
    for region in "${REGION_ARRAY[@]}"; do
        echo "./setup-eks-cluster.sh ghost-protocol $region $INSTANCE_TYPE 1 $NODES_PER_REGION --spot"
    done
fi

# Create cost report
REPORT_FILE="cost-estimate-$(date +%Y%m%d_%H%M%S).json"
cat > $REPORT_FILE << EOF
{
  "estimate_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "parameters": {
    "total_urls": $TOTAL_URLS,
    "regions": "$REGIONS",
    "num_regions": $NUM_REGIONS,
    "instance_type": "$INSTANCE_TYPE",
    "use_spot": $USE_SPOT
  },
  "processing": {
    "total_chunks": $TOTAL_CHUNKS,
    "chunks_per_region": $CHUNKS_PER_REGION,
    "hours_per_chunk": $HOURS_PER_CHUNK,
    "total_processing_hours": $TOTAL_PROCESSING_HOURS,
    "nodes_per_region": $NODES_PER_REGION
  },
  "costs": {
    "eks_processing": $EKS_PROCESSING_COST,
    "worker_nodes": $TOTAL_NODE_COST,
    "additional_services": $(echo "$ECR_COST + $DATA_TRANSFER + $S3_STORAGE" | bc -l),
    "total_processing": $TOTAL_PROCESSING_COST,
    "monthly_if_kept_running": $TOTAL_MONTHLY_COST,
    "cost_per_url": $COST_PER_URL,
    "cost_per_1000_urls": $COST_PER_1000_URLS
  },
  "performance": {
    "single_region_hours": $TOTAL_PROCESSING_TIME_SINGLE,
    "multi_region_hours": $TOTAL_PROCESSING_TIME_PARALLEL,
    "speedup_factor": $SPEEDUP
  }
}
EOF

echo "Cost estimate saved to: $REPORT_FILE"