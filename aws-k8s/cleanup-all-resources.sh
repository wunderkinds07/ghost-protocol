#!/bin/bash
# Emergency cleanup script - deletes ALL Ghost Protocol resources

set -e

REGIONS=${1:-"us-east-1,us-west-2,eu-west-1,us-west-1,eu-central-1,ap-southeast-1"}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}⚠️  EMERGENCY CLEANUP - This will delete ALL Ghost Protocol resources ⚠️${NC}"
echo ""
echo "This will delete:"
echo "  • All EKS clusters named 'ghost-protocol'"
echo "  • All ECR repositories named 'ghost-protocol'"  
echo "  • All associated Load Balancers, VPCs, etc."
echo ""
echo "Regions to clean: $REGIONS"
echo ""

read -p "Are you sure you want to continue? Type 'DELETE' to confirm: " confirmation
if [ "$confirmation" != "DELETE" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup across all regions...${NC}"

# Convert regions to array
IFS=',' read -ra REGION_ARRAY <<< "$REGIONS"

# Track what we find and delete
CLUSTERS_FOUND=0
CLUSTERS_DELETED=0
ECR_REPOS_FOUND=0
ECR_REPOS_DELETED=0

for REGION in "${REGION_ARRAY[@]}"; do
    echo ""
    echo -e "${YELLOW}Cleaning region: $REGION${NC}"
    
    # Check for EKS clusters
    CLUSTERS=$(aws eks list-clusters --region $REGION --query 'clusters' --output text 2>/dev/null | grep ghost-protocol || true)
    
    if [ ! -z "$CLUSTERS" ]; then
        for CLUSTER in $CLUSTERS; do
            echo "  Found EKS cluster: $CLUSTER"
            CLUSTERS_FOUND=$((CLUSTERS_FOUND + 1))
            
            echo "  Deleting EKS cluster: $CLUSTER (this may take 10-15 minutes)..."
            if eksctl delete cluster --name $CLUSTER --region $REGION --wait; then
                echo "  ✅ Deleted cluster: $CLUSTER"
                CLUSTERS_DELETED=$((CLUSTERS_DELETED + 1))
            else
                echo -e "  ${RED}❌ Failed to delete cluster: $CLUSTER${NC}"
            fi
        done
    else
        echo "  No ghost-protocol clusters found"
    fi
    
    # Check for ECR repositories
    ECR_REPOS=$(aws ecr describe-repositories --region $REGION --query 'repositories[?repositoryName==`ghost-protocol`].repositoryName' --output text 2>/dev/null || true)
    
    if [ ! -z "$ECR_REPOS" ]; then
        echo "  Found ECR repository: ghost-protocol"
        ECR_REPOS_FOUND=$((ECR_REPOS_FOUND + 1))
        
        echo "  Deleting ECR repository..."
        if aws ecr delete-repository --repository-name ghost-protocol --region $REGION --force; then
            echo "  ✅ Deleted ECR repository"
            ECR_REPOS_DELETED=$((ECR_REPOS_DELETED + 1))
        else
            echo -e "  ${RED}❌ Failed to delete ECR repository${NC}"
        fi
    else
        echo "  No ghost-protocol ECR repositories found"
    fi
    
    # Clean up any orphaned resources
    echo "  Checking for orphaned Load Balancers..."
    LBS=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName,`ghost-protocol`)].LoadBalancerArn' --output text 2>/dev/null || true)
    
    if [ ! -z "$LBS" ]; then
        for LB in $LBS; do
            echo "  Deleting Load Balancer: $LB"
            aws elbv2 delete-load-balancer --load-balancer-arn $LB --region $REGION || true
        done
    fi
    
    # Check for any running EC2 instances with ghost-protocol tag
    echo "  Checking for tagged EC2 instances..."
    INSTANCES=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=*ghost-protocol*" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)
    
    if [ ! -z "$INSTANCES" ]; then
        echo "  Found tagged instances: $INSTANCES"
        echo "  Terminating instances..."
        aws ec2 terminate-instances --instance-ids $INSTANCES --region $REGION || true
    fi
done

# Clean up local files
echo ""
echo -e "${YELLOW}Cleaning up local files...${NC}"
rm -f cluster-info-*.json
rm -f image-uri-*.txt  
rm -f deployment-plan-*.json
rm -f cost-estimate-*.json
rm -f monitor-jobs-*.sh
rm -f monitor-all-regions.sh
rm -f collect-all-results.sh
rm -rf multi-region-results-*
rm -rf results-k8s-*
rm -rf chunks-*

echo "✅ Local files cleaned up"

# Summary
echo ""
echo -e "${GREEN}=== CLEANUP SUMMARY ===${NC}"
echo "EKS Clusters:"
echo "  Found: $CLUSTERS_FOUND"
echo "  Deleted: $CLUSTERS_DELETED"
echo ""
echo "ECR Repositories:"
echo "  Found: $ECR_REPOS_FOUND" 
echo "  Deleted: $ECR_REPOS_DELETED"
echo ""

if [ $CLUSTERS_DELETED -eq $CLUSTERS_FOUND ] && [ $ECR_REPOS_DELETED -eq $ECR_REPOS_FOUND ]; then
    echo -e "${GREEN}✅ All resources successfully cleaned up!${NC}"
    echo ""
    echo "💰 Your AWS bill should stop increasing now."
    echo "🔍 Check AWS Console to verify all resources are gone."
else
    echo -e "${RED}⚠️  Some resources may not have been deleted.${NC}"
    echo "Please check AWS Console manually and delete any remaining resources."
fi

echo ""
echo "Next steps:"
echo "1. Check AWS Console → EC2 → Running Instances"
echo "2. Check AWS Console → EKS → Clusters"  
echo "3. Check AWS Console → ECR → Repositories"
echo "4. Monitor your AWS bill for the next few days"

# Create cleanup report
CLEANUP_REPORT="cleanup-report-$(date +%Y%m%d_%H%M%S).txt"
cat > $CLEANUP_REPORT << EOF
Ghost Protocol Cleanup Report
============================
Date: $(date)
Regions checked: $REGIONS

Resources found and deleted:
- EKS Clusters: $CLUSTERS_DELETED/$CLUSTERS_FOUND
- ECR Repositories: $ECR_REPOS_DELETED/$ECR_REPOS_FOUND

Cleanup status: $([ $CLUSTERS_DELETED -eq $CLUSTERS_FOUND ] && [ $ECR_REPOS_DELETED -eq $ECR_REPOS_FOUND ] && echo "COMPLETE" || echo "PARTIAL")

Note: Please verify in AWS Console that all resources are deleted.
Check your AWS billing for the next few days to ensure charges have stopped.
EOF

echo ""
echo "Cleanup report saved to: $CLEANUP_REPORT"