#!/bin/bash

# Deployment script for 1stDibs extraction containers

echo "🚀 1stDibs Data Extraction Deployment Script"
echo "==========================================="

# Function to create URL chunks
create_url_chunks() {
    echo "📄 Creating URL chunks..."
    
    # Check if main URL file exists
    if [ ! -f "../1m-urls-1stdibs-raw.txt" ]; then
        echo "❌ Error: 1m-urls-1stdibs-raw.txt not found!"
        exit 1
    fi
    
    # Create chunks directory
    mkdir -p chunks
    
    # Split the file into 5000-line chunks
    split -l 5000 ../1m-urls-1stdibs-raw.txt chunks/urls_chunk_
    
    echo "✅ Created URL chunks in chunks/ directory"
}

# Function to deploy single container
deploy_container() {
    local container_id=$1
    local start_index=$2
    local chunk_size=5000
    
    echo "🐳 Deploying container $container_id (URLs $start_index-$((start_index + chunk_size - 1)))"
    
    # Create data directory for container
    mkdir -p data/container${container_id}/{raw_html,extracted,logs}
    
    # Copy the appropriate chunk
    chunk_file="chunks/urls_chunk_$(printf "%02d" $((container_id - 1)))"
    if [ -f "$chunk_file" ]; then
        cp "$chunk_file" "data/container${container_id}/urls_chunk.txt"
    fi
    
    # Run container
    docker run -d \
        --name "1stdibs-extractor-${container_id}" \
        -e CONTAINER_ID="${container_id}" \
        -e URL_CHUNK_START="${start_index}" \
        -e URL_CHUNK_SIZE="${chunk_size}" \
        -v "$(pwd)/data/container${container_id}:/app/data" \
        1stdibs-extractor:latest
    
    echo "✅ Container $container_id deployed"
}

# Function to deploy with docker-compose
deploy_compose() {
    echo "🐳 Building Docker image..."
    docker build -t 1stdibs-extractor:latest -f Dockerfile ..
    
    echo "🚀 Starting containers with docker-compose..."
    docker-compose up -d
    
    echo "✅ All containers deployed!"
    echo ""
    echo "📊 Monitor progress with:"
    echo "   docker-compose logs -f"
    echo "   docker-compose ps"
}

# Function to deploy standalone containers
deploy_standalone() {
    local num_containers=$1
    
    echo "🐳 Building Docker image..."
    docker build -t 1stdibs-extractor:latest -f Dockerfile ..
    
    # Deploy containers
    for i in $(seq 1 $num_containers); do
        start_index=$(( (i - 1) * 5000 ))
        deploy_container $i $start_index
    done
    
    echo "✅ Deployed $num_containers containers"
}

# Main menu
echo ""
echo "Select deployment method:"
echo "1) Docker Compose (recommended for local)"
echo "2) Standalone containers"
echo "3) Create URL chunks only"
echo "4) Build image only"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        deploy_compose
        ;;
    2)
        read -p "How many containers to deploy? " num_containers
        deploy_standalone $num_containers
        ;;
    3)
        create_url_chunks
        ;;
    4)
        docker build -t 1stdibs-extractor:latest -f Dockerfile ..
        echo "✅ Image built: 1stdibs-extractor:latest"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📈 Check container status:"
echo "   docker ps | grep 1stdibs"
echo ""
echo "📊 View logs:"
echo "   docker logs 1stdibs-extractor-1"
echo ""
echo "📁 Data location:"
echo "   ./data/container[ID]/raw_html/     - Compressed HTML files"
echo "   ./data/container[ID]/extracted/    - Extracted JSON data"
echo "   ./data/container[ID]/logs/         - Processing logs"