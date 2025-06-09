#!/bin/bash
# Manual test commands to run on your Lightsail instance
# SSH into your instance first, then run these commands

echo "🧪 Ghost Protocol Manual Test"
echo "============================="

# Install Docker if needed
echo "📦 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "⚠️  Please logout and login again, then re-run this script"
    exit 1
fi

# Clone repository
echo "📥 Cloning repository..."
git clone https://github.com/wunderkinds07/ghost-protocol.git
cd ghost-protocol

# Build Docker image
echo "🐳 Building Docker image..."
docker build -f docker/Dockerfile -t ghost-protocol .
if [ $? -ne 0 ]; then
    echo "❌ Docker build failed"
    exit 1
fi
echo "✅ Docker build successful"

# Test 1: Single container
echo ""
echo "🧪 Test 1: Single Container"
echo "---------------------------"
docker run -d \
    --name ghost-test \
    -e CONTAINER_ID=test \
    -e URL_CHUNK_START=0 \
    -e URL_CHUNK_SIZE=3 \
    -e NTFY_TOPIC=ghost-test \
    -v $(pwd)/data:/app/data \
    -v $(pwd)/chunks/test_urls.txt:/app/data/urls_chunk.txt:ro \
    ghost-protocol

echo "⏳ Waiting 45 seconds for processing..."
sleep 45

echo ""
echo "📊 Single Container Results:"
echo "============================"
echo "Container status:"
docker ps --filter name=ghost-test --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "Last 10 log lines:"
docker logs ghost-test | tail -10

echo ""
echo "Files extracted:"
find data -name "*.json" 2>/dev/null | wc -l

echo ""
echo "HTML files saved:"
find data -name "*.gz" 2>/dev/null | wc -l

# Cleanup
docker stop ghost-test && docker rm ghost-test

# Test 2: Multi-container
echo ""
echo "🧪 Test 2: Multi-Container (3 containers)"
echo "-----------------------------------------"
for i in {1..3}; do
    echo "Starting container $i..."
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

echo "⏳ Waiting 60 seconds for all containers..."
sleep 60

echo ""
echo "📊 Multi-Container Results:"
echo "============================"
docker ps --filter name=ghost-scale --format "table {{.Names}}\t{{.Status}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "Total files extracted:"
find data -name "*.json" 2>/dev/null | wc -l

echo ""
echo "Per-container logs (last 3 lines each):"
for i in {1..3}; do
    echo ""
    echo "--- Container $i logs ---"
    docker logs ghost-scale-$i | tail -3
    echo "Files: $(find data/container$i -name "*.json" 2>/dev/null | wc -l)"
done

echo ""
echo "📈 Resource Usage:"
docker stats --no-stream --filter name=ghost-scale

# Cleanup
echo ""
echo "🧹 Cleaning up..."
docker stop $(docker ps -q --filter name=ghost-scale) 2>/dev/null || true
docker rm $(docker ps -aq --filter name=ghost-scale) 2>/dev/null || true

echo ""
echo "🎯 Test Summary:"
echo "==============="
echo "✅ If you see extracted files and running containers above, the test passed!"
echo "✅ Expected: 3 files from single container + 6 files from multi-container = 9 total"
echo "✅ All containers should show 'Exited (0)' status (successful completion)"
echo ""
echo "🚀 If tests passed, you're ready for production deployment!"