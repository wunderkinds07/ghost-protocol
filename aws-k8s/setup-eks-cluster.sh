#!/bin/bash
# Setup EKS cluster for Ghost Protocol in specified region

set -e

# Configuration
CLUSTER_NAME=${1:-ghost-protocol}
REGION=${2:-us-east-1}
NODE_TYPE=${3:-t3.medium}
MIN_NODES=${4:-1}
MAX_NODES=${5:-10}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Setting up EKS cluster in $REGION ===${NC}"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Node type: $NODE_TYPE"
echo "Node range: $MIN_NODES - $MAX_NODES"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI not found. Please install: https://aws.amazon.com/cli/${NC}"
    exit 1
fi

if ! command -v eksctl &> /dev/null; then
    echo -e "${RED}eksctl not found. Installing eksctl...${NC}"
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Installing kubectl...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

echo -e "${GREEN}✓ Prerequisites checked${NC}"

# Create EKS cluster
echo -e "${YELLOW}Creating EKS cluster (this takes 15-20 minutes)...${NC}"
eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --node-type $NODE_TYPE \
    --nodes $MIN_NODES \
    --nodes-min $MIN_NODES \
    --nodes-max $MAX_NODES \
    --with-oidc \
    --ssh-access \
    --ssh-public-key ~/.ssh/id_rsa.pub \
    --managed

echo -e "${GREEN}✓ EKS cluster created${NC}"

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verify cluster
echo -e "${YELLOW}Verifying cluster...${NC}"
kubectl get nodes

# Install AWS Load Balancer Controller (for ingress)
echo -e "${YELLOW}Installing AWS Load Balancer Controller...${NC}"
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json || true

eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region=$REGION || true

# Install AWS Load Balancer Controller via Helm
helm repo add eks https://aws.github.io/eks-charts || true
helm repo update
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.resourcesVpcConfig.vpcId" --output text) || true

echo -e "${GREEN}✓ AWS Load Balancer Controller installed${NC}"

# Create ECR repository for Ghost Protocol image
echo -e "${YELLOW}Creating ECR repository...${NC}"
aws ecr create-repository --repository-name ghost-protocol --region $REGION || true

# Get ECR login
ECR_URI=$(aws ecr describe-repositories --repository-names ghost-protocol --region $REGION --query 'repositories[0].repositoryUri' --output text)
echo -e "${BLUE}ECR Repository: $ECR_URI${NC}"

# Save cluster info
cat > cluster-info-$REGION.json << EOF
{
  "cluster_name": "$CLUSTER_NAME",
  "region": "$REGION",
  "ecr_uri": "$ECR_URI",
  "node_type": "$NODE_TYPE",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo -e "${GREEN}=== EKS Cluster Setup Complete ===${NC}"
echo "Cluster name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "ECR repository: $ECR_URI"
echo "Info saved to: cluster-info-$REGION.json"
echo ""
echo "Next steps:"
echo "1. Build and push Docker image: ./build-and-push-image.sh $REGION"
echo "2. Deploy Ghost Protocol: ./deploy-ghost-protocol.sh $REGION"

# Cleanup
rm -f iam_policy.json