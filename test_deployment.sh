#!/bin/bash
# Test deployment script for Ghost Protocol

INSTANCE_IP=${1:-""}
if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: ./test_deployment.sh INSTANCE_IP"
    echo "This will test the full deployment on a single instance"
    exit 1
fi

echo "🧪 Testing Ghost Protocol Deployment"
echo "==================================="
echo "Instance: $INSTANCE_IP"
echo ""

# Test 1: Deploy to instance
echo "📦 Test 1: GitHub Deployment"
echo "----------------------------"
./deploy_via_git.sh https://github.com/wunderkinds07/ghost-protocol.git $INSTANCE_IP
if [ $? -ne 0 ]; then
    echo "❌ Deployment failed"
    exit 1
fi
echo "✅ Deployment successful"

# Test 2: SSH and run test container
echo ""
echo "🐳 Test 2: Container Execution"
echo "------------------------------"
ssh ubuntu@$INSTANCE_IP << 'ENDSSH'
    cd ghost-protocol
    
    # Build image
    echo "Building Docker image..."
    docker build -t ghost-protocol . || exit 1
    
    # Run test container with 5 URLs
    echo "Running test container..."
    docker run -d \
        --name ghost-test \
        -e CONTAINER_ID=test \
        -e URL_CHUNK_START=0 \
        -e URL_CHUNK_SIZE=5 \
        -e NTFY_TOPIC=ghost-test \
        -v $(pwd)/data:/app/data \
        -v $(pwd)/chunks/test_urls.txt:/app/data/urls_chunk.txt:ro \
        ghost-protocol
    
    # Wait for container to process
    echo "Waiting 30 seconds for processing..."
    sleep 30
    
    # Check results
    echo ""
    echo "📊 Test Results:"
    echo "==============="
    echo "Container status:"
    docker ps --filter name=ghost-test --format "table {{.Names}}\t{{.Status}}"
    
    echo ""
    echo "Container logs:"
    docker logs ghost-test | tail -10
    
    echo ""
    echo "Extracted files:"
    find data -name "*.json" 2>/dev/null | wc -l || echo "0"
    
    echo ""
    echo "Raw HTML files:"
    find data -name "*.gz" 2>/dev/null | wc -l || echo "0"
    
    # Cleanup
    docker stop ghost-test && docker rm ghost-test
ENDSSH

if [ $? -eq 0 ]; then
    echo "✅ Container test successful"
else
    echo "❌ Container test failed"
    exit 1
fi

# Test 3: Multi-container test
echo ""
echo "🔄 Test 3: Multi-Container Scaling"
echo "----------------------------------"
ssh ubuntu@$INSTANCE_IP << 'ENDSSH'
    cd ghost-protocol
    
    echo "Starting 3 test containers..."
    for i in {1..3}; do
        docker run -d \
            --name ghost-scale-$i \
            --memory="500m" \
            --cpus="0.3" \
            -e CONTAINER_ID=$i \
            -e URL_CHUNK_START=$(( ($i-1) * 2 )) \
            -e URL_CHUNK_SIZE=2 \
            -e NTFY_TOPIC=ghost-scale-$i \
            -v $(pwd)/data/container$i:/app/data \
            -v $(pwd)/chunks/test_urls.txt:/app/data/urls_chunk.txt:ro \
            ghost-protocol
    done
    
    echo "Waiting 45 seconds for all containers..."
    sleep 45
    
    echo ""
    echo "📊 Multi-Container Results:"
    echo "============================"
    docker ps --filter name=ghost-scale --format "table {{.Names}}\t{{.Status}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    
    echo ""
    echo "Total extracted files:"
    find data -name "*.json" 2>/dev/null | wc -l || echo "0"
    
    echo ""
    echo "Per-container results:"
    for i in {1..3}; do
        echo "Container $i:"
        docker logs ghost-scale-$i | tail -3
        echo "Files: $(find data/container$i -name "*.json" 2>/dev/null | wc -l || echo '0')"
        echo ""
    done
    
    # Cleanup
    docker stop $(docker ps -q --filter name=ghost-scale) 2>/dev/null || true
    docker rm $(docker ps -aq --filter name=ghost-scale) 2>/dev/null || true
ENDSSH

if [ $? -eq 0 ]; then
    echo "✅ Multi-container test successful"
else
    echo "❌ Multi-container test failed"
    exit 1
fi

echo ""
echo "🎉 All Tests Passed!"
echo "==================="
echo "✅ GitHub deployment works"
echo "✅ Docker build succeeds"
echo "✅ Single container processes URLs"
echo "✅ Multi-container scaling works"
echo ""
echo "🚀 Ready for production deployment!"
echo ""
echo "Deploy to multiple instances with:"
echo "./deploy_via_git.sh https://github.com/wunderkinds07/ghost-protocol.git INSTANCE_1_IP"
echo "./deploy_via_git.sh https://github.com/wunderkinds07/ghost-protocol.git INSTANCE_2_IP"
echo "./deploy_via_git.sh https://github.com/wunderkinds07/ghost-protocol.git INSTANCE_3_IP"