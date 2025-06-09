#!/bin/bash

echo "🔍 Verifying 1stDibs Extractor Deployment"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check function
check() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        exit 1
    fi
}

# 1. Check Docker
echo -e "\n${YELLOW}1. Checking Docker...${NC}"
docker --version > /dev/null 2>&1
check $? "Docker is installed"

# 2. Check Python
echo -e "\n${YELLOW}2. Checking Python...${NC}"
python3 --version > /dev/null 2>&1
check $? "Python is installed"

# 3. Check project structure
echo -e "\n${YELLOW}3. Checking project structure...${NC}"
[ -d "src" ] && check 0 "src/ directory exists" || check 1 "src/ directory missing"
[ -d "docker" ] && check 0 "docker/ directory exists" || check 1 "docker/ directory missing"
[ -d "deployment" ] && check 0 "deployment/ directory exists" || check 1 "deployment/ directory missing"

# 4. Check key files
echo -e "\n${YELLOW}4. Checking key files...${NC}"
[ -f "docker/Dockerfile" ] && check 0 "Dockerfile exists" || check 1 "Dockerfile missing"
[ -f "deployment/chunk_names.json" ] && check 0 "chunk_names.json exists" || check 1 "chunk_names.json missing"
[ -f "deployment/prepare_chunks.py" ] && check 0 "prepare_chunks.py exists" || check 1 "prepare_chunks.py missing"

# 5. Check Python modules
echo -e "\n${YELLOW}5. Checking Python modules...${NC}"
[ -f "src/parsers/html_collector.py" ] && check 0 "html_collector.py exists" || check 1 "html_collector.py missing"
[ -f "src/extractors/product_extractor.py" ] && check 0 "product_extractor.py exists" || check 1 "product_extractor.py missing"

# 6. Check documentation
echo -e "\n${YELLOW}6. Checking documentation...${NC}"
[ -f "README.md" ] && check 0 "README.md exists" || check 1 "README.md missing"
[ -f "PROJECT_SUMMARY.md" ] && check 0 "PROJECT_SUMMARY.md exists" || check 1 "PROJECT_SUMMARY.md missing"
[ -f "DETAILED_PROJECT_DOCUMENTATION.md" ] && check 0 "DETAILED_PROJECT_DOCUMENTATION.md exists" || check 1 "DETAILED_PROJECT_DOCUMENTATION.md missing"
[ -f "TECHNICAL_SPECIFICATION.md" ] && check 0 "TECHNICAL_SPECIFICATION.md exists" || check 1 "TECHNICAL_SPECIFICATION.md missing"

# 7. Test Docker build
echo -e "\n${YELLOW}7. Testing Docker build...${NC}"
echo "Building test image..."
docker build -t 1stdibs-test:verify -f docker/Dockerfile . > /dev/null 2>&1
check $? "Docker image builds successfully"

# Clean up
docker rmi 1stdibs-test:verify > /dev/null 2>&1

# 8. Check scripts are executable
echo -e "\n${YELLOW}8. Checking script permissions...${NC}"
[ -x "test_local.sh" ] && check 0 "test_local.sh is executable" || check 1 "test_local.sh needs chmod +x"
[ -x "setup_github.sh" ] && check 0 "setup_github.sh is executable" || check 1 "setup_github.sh needs chmod +x"

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 All checks passed! Project is ready.${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Quick Start Commands:${NC}"
echo "1. Test locally:        ./test_local.sh"
echo "2. Prepare deployment:  python deployment/prepare_chunks.py urls.txt 5000"
echo "3. Build images:        ./deployment/build_images.sh"
echo "4. Deploy containers:   docker-compose -f deployment/docker-compose.yml up -d"
echo "5. Push to GitHub:      ./setup_github.sh"

echo -e "\n${YELLOW}Documentation:${NC}"
echo "- Quick overview:       cat PROJECT_SUMMARY.md"
echo "- Full details:         cat DETAILED_PROJECT_DOCUMENTATION.md"
echo "- Technical specs:      cat TECHNICAL_SPECIFICATION.md"