#!/bin/bash

echo "🧪 Testing 1stDibs Extractor Locally"
echo "===================================="

# Build base image
echo "📦 Building Docker image..."
docker build -t 1stdibs-extractor:latest -f docker/Dockerfile .

# Create test chunk
echo "📝 Creating test chunk..."
cat > test_chunk.txt << EOF
https://www.1stdibs.com/furniture/mirrors/pier-mirrors-console-mirrors/italian-parcel-ebonized-walnut-mirror-18th-century-great-color-scale/id-f_10001073/
https://www.1stdibs.com/furniture/mirrors/wall-mirrors/italian-baroque-giltwood-mirror-18th-century/id-f_18765432/
https://www.1stdibs.com/furniture/tables/dining-room-tables/italian-marble-dining-table-oval-1970s/id-f_28765432/
EOF

# Run test container
echo "🐳 Running test container..."
echo "📢 Notifications will be sent to: https://ntfy.sh/callofdutyblackopsghostprotocolbravo64"
echo ""
mkdir -p test_output

docker run --rm \
  -e CONTAINER_ID=test-phoenix \
  -e CHUNK_NAME=phoenix \
  -e URL_CHUNK_START=0 \
  -e URL_CHUNK_SIZE=3 \
  -e NTFY_TOPIC=callofdutyblackopsghostprotocolbravo64 \
  -v $(pwd)/test_chunk.txt:/app/data/urls_chunk.txt:ro \
  -v $(pwd)/test_output:/app/data \
  1stdibs-extractor:latest

# Check results
echo ""
echo "📊 Test Results:"
echo "==============="

if [ -f test_output/container_test-phoenix_summary.json ]; then
    echo "✅ Summary file created"
    cat test_output/container_test-phoenix_summary.json
else
    echo "❌ Summary file not found"
fi

echo ""
echo "📁 Output files:"
ls -la test_output/extracted/ 2>/dev/null || echo "No extracted files found"

echo ""
echo "🎉 Test complete!"