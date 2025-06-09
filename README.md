# 🚀 Ghost Protocol - Multi-Region Web Scraping at Scale

Complete AWS + Kubernetes deployment system for processing millions of URLs across multiple regions with automatic scaling and cost optimization.

## 🎯 Quick Start Options

### 1. AWS CloudShell (Recommended - Zero Setup)
```bash
# Just open AWS CloudShell and run:
curl -s https://raw.githubusercontent.com/YOUR_USERNAME/ghost-protocol/main/aws-cloudshell/setup-cloudshell.sh  < /dev/null |  bash
```

### 2. Local CLI Deployment
```bash
# Clone and deploy
git clone https://github.com/YOUR_USERNAME/ghost-protocol.git
cd ghost-protocol/aws-k8s
./deploy-multi-region.sh "us-east-1,us-west-2,eu-west-1" 50
```

### 3. GUI Deployment
Follow the [AWS GUI Deployment Guide](AWS_GUI_DEPLOYMENT_GUIDE.md) for point-and-click deployment.

## 📊 What You Get

- **Multi-region processing** across AWS regions
- **Kubernetes auto-scaling** with EKS clusters
- **Docker containerized** processing pipeline
- **Cost optimization** with spot instances
- **Real-time monitoring** across all regions
- **Automatic data collection** and merging
- **One-click cleanup** to control costs

## 🎬 Demo Results

Successfully tested with 1stDibs furniture marketplace:
- **Processed**: 5 test URLs in under 2 minutes
- **Extracted**: Complete product data including titles, prices, categories, materials
- **Success rate**: 100% for valid URLs
- **Output**: Structured JSON with 15+ data fields per product

## 📁 Repository Structure

```
ghost-protocol/
├── aws-cloudshell/          # Browser-based deployment (easiest)
├── aws-k8s/                 # Full Kubernetes deployment
├── aws-gui/                 # GUI-based deployment options
├── k8s/                     # Kubernetes manifests
├── docker/                  # Container definitions
├── src/                     # Processing pipeline code
├── *.md                     # Documentation and guides
└── *.py                     # Utility scripts
```

## 💰 Cost Examples

| Scale | Regions | Time | Cost (Spot) | Cost (On-Demand) |
|-------|---------|------|-------------|------------------|
| 1K URLs | 1 | 30 min | $3 | $8 |
| 10K URLs | 2 | 2 hours | $15 | $35 |
| 100K URLs | 3 | 8 hours | $45 | $120 |
| 1M URLs | 3 | 33 hours | $90 | $280 |

## 🚀 Deployment Guides

### For Beginners
- [CloudShell Copy-Paste Guide](CLOUDSHELL_COPY_PASTE.md) - Zero setup required
- [Complete Setup Guide](COMPLETE_SETUP_GUIDE.md) - Full walkthrough
- [Step-by-Step Commands](STEP_BY_STEP_COMMANDS.md) - Exact commands to run

### For Advanced Users
- [AWS Kubernetes Guide](AWS_KUBERNETES_GUIDE.md) - Technical deep dive
- [Multi-Region Deployment](aws-k8s/deploy-multi-region.sh) - Scale across regions
- [Cost Optimization](aws-k8s/cost-estimator.sh) - Estimate and optimize costs

### For GUI Users
- [AWS GUI Deployment](AWS_GUI_DEPLOYMENT_GUIDE.md) - Point-and-click deployment
- [CloudFormation Template](aws-gui/cloudformation-template.yaml) - One-click infrastructure

## 🔧 Quick Commands

```bash
# Estimate costs
./aws-k8s/cost-estimator.sh 100000 "us-east-1,us-west-2" t3.medium true

# Deploy single region
./simple_deploy.sh 1 your-instance-ip

# Deploy multi-region
./aws-k8s/deploy-multi-region.sh "us-east-1,us-west-2,eu-west-1" 50

# Monitor progress
./aws-k8s/monitor-all-regions.sh

# Collect results
./aws-k8s/collect-all-results.sh

# Emergency cleanup
./aws-k8s/cleanup-all-resources.sh
```

Start with the [CloudShell deployment](CLOUDSHELL_COPY_PASTE.md) for immediate results! 🚀
