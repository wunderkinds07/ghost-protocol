#!/bin/bash
# Test the simple deployment system locally

set -e

echo "=== Testing Simple Deployment System ==="

# Create test URLs file if it doesn't exist
if [ ! -f "test_urls_5k.txt" ]; then
    echo "Creating test URLs file with 15 URLs..."
    cat > test_urls_5k.txt << 'EOF'
https://www.1stdibs.com/furniture/seating/benches/mid-century-modern-wooden-bench-unknown-danish-cabinetmaker-1960s/id-f_31310552/
https://www.1stdibs.com/furniture/seating/chairs/mid-century-modern-stacking-chairs-verner-panton-herman-miller-1960s/id-f_1234567/
https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-modern-dining-table-carlo-scarpa-1970s/id-f_2345678/
https://www.1stdibs.com/furniture/storage-case-pieces/cabinets/danish-modern-teak-cabinet-arne-vodder-1960s/id-f_3456789/
https://www.1stdibs.com/furniture/lighting/floor-lamps/italian-arc-floor-lamp-achille-castiglioni-flos-1962/id-f_4567890/
https://www.1stdibs.com/furniture/seating/sofas/scandinavian-modern-sofa-finn-juhl-1950s/id-f_5678901/
https://www.1stdibs.com/furniture/tables/coffee-tables-cocktail-tables/glass-coffee-table-isamu-noguchi-herman-miller/id-f_6789012/
https://www.1stdibs.com/furniture/seating/lounge-chairs/barcelona-chair-mies-van-der-rohe-knoll-1929/id-f_7890123/
https://www.1stdibs.com/furniture/storage-case-pieces/desks/executive-desk-george-nelson-herman-miller-1960s/id-f_8901234/
https://www.1stdibs.com/furniture/lighting/chandeliers-pendant-lights/murano-glass-chandelier-venini-1970s/id-f_9012345/
https://www.1stdibs.com/furniture/seating/stools/piano-stool-alvar-aalto-artek-1930s/id-f_10123456/
https://www.1stdibs.com/furniture/tables/side-tables/marble-side-table-eero-saarinen-knoll-1956/id-f_11234567/
https://www.1stdibs.com/furniture/mirrors/wall-mirrors/sunburst-mirror-line-vautrin-1960s/id-f_12345678/
https://www.1stdibs.com/furniture/seating/armchairs/leather-armchair-le-corbusier-cassina-1928/id-f_13456789/
https://www.1stdibs.com/furniture/storage-case-pieces/bookcases/modular-bookcase-dieter-rams-vitsoe-1960/id-f_14567890/
EOF
fi

# Step 1: Create chunks
echo ""
echo "Step 1: Creating URL chunks (5 URLs per chunk for testing)..."
python prepare_chunks.py test_urls_5k.txt 5 test_chunks

echo ""
echo "Chunks created:"
ls -la test_chunks/

# Step 2: Show deployment commands
echo ""
echo "Step 2: Example deployment commands:"
echo ""
echo "For single instance deployment:"
echo "  ./simple_deploy.sh 1 <instance-ip>"
echo ""
echo "For multi-instance deployment:"
echo "  1. Create instances.txt with IP addresses"
echo "  2. Run: ./deploy_multi_instance.sh instances.txt"
echo ""

# Step 3: Test locally with Docker (optional)
echo "Step 3: Test locally with Docker? (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Testing chunk 1 locally with Docker..."
    
    # Create local test directory
    LOCAL_TEST_DIR="local_test_chunk_1"
    rm -rf $LOCAL_TEST_DIR
    mkdir -p $LOCAL_TEST_DIR
    
    # Copy Docker files
    cp -r docker/* $LOCAL_TEST_DIR/
    cp test_chunks/urls_chunk_0001.txt $LOCAL_TEST_DIR/urls_chunk.txt
    
    # Create docker-compose for local test
    cat > $LOCAL_TEST_DIR/docker-compose.yml << 'EOF'
version: '3.8'

services:
  processor:
    build: .
    container_name: ghost-test-local
    environment:
      - URLS_FILE=/app/urls_chunk.txt
      - CONTAINER_ID=test-local
      - OUTPUT_DIR=/app/data
    volumes:
      - ./data:/app/data
      - ./urls_chunk.txt:/app/urls_chunk.txt:ro
EOF
    
    cd $LOCAL_TEST_DIR
    echo "Starting Docker container..."
    docker-compose up -d --build
    
    echo ""
    echo "Container started. Check logs with:"
    echo "  docker logs -f ghost-test-local"
    echo ""
    echo "Stop container with:"
    echo "  cd $LOCAL_TEST_DIR && docker-compose down"
    
    cd ..
fi

echo ""
echo "=== Test Setup Complete ==="
echo ""
echo "Test chunks created in: test_chunks/"
echo "You can now deploy to real instances using the deployment scripts."

# Clean up
echo ""
echo "To clean up test files:"
echo "  rm -rf test_chunks test_urls_5k.txt local_test_chunk_1"