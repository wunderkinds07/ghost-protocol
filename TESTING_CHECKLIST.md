# Ghost Protocol Testing Checklist

## 🧪 Pre-Deployment Testing

### Test 1: Automated Full Test
```bash
./test_deployment.sh YOUR_INSTANCE_IP
```
This runs all tests automatically.

### Test 2: Manual Step-by-Step Test

#### 2.1 Deploy to Instance
```bash
./deploy_via_git.sh https://github.com/wunderkinds07/ghost-protocol.git YOUR_INSTANCE_IP
```

#### 2.2 SSH and Test Build
```bash
ssh ubuntu@YOUR_INSTANCE_IP
cd ghost-protocol
docker build -t ghost-protocol .
```

#### 2.3 Test Single Container
```bash
docker run -d --name test-ghost \
  -e CONTAINER_ID=test \
  -e URL_CHUNK_SIZE=3 \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/chunks/test_urls.txt:/app/data/urls_chunk.txt:ro \
  ghost-protocol

# Wait 30 seconds
sleep 30

# Check results
docker logs test-ghost
find data -name "*.json" | wc -l
```

#### 2.4 Test Multi-Container
```bash
for i in {1..3}; do
  docker run -d --name ghost-$i \
    -e CONTAINER_ID=$i \
    -e URL_CHUNK_START=$(( ($i-1) * 2 )) \
    -e URL_CHUNK_SIZE=2 \
    -v $(pwd)/data/container$i:/app/data \
    -v $(pwd)/chunks/test_urls.txt:/app/data/urls_chunk.txt:ro \
    ghost-protocol
done

# Monitor
docker ps
docker stats --no-stream
```

## ✅ Expected Results

### Single Container Test
- ✅ Container starts successfully
- ✅ Processes 3 URLs
- ✅ Creates 3 JSON files in `data/extracted/`
- ✅ Creates 3 HTML.gz files in `data/raw_html/`
- ✅ Logs show successful completion

### Multi-Container Test
- ✅ All 3 containers start
- ✅ Each processes 2 URLs
- ✅ Total 6 files extracted
- ✅ No container crashes
- ✅ Memory usage < 800MB per container

## 🚨 Troubleshooting

### Container Won't Start
```bash
docker logs CONTAINER_NAME
# Check for Python import errors or missing files
```

### No Files Extracted
```bash
docker exec -it CONTAINER_NAME ls /app/data/
# Check if directories exist and permissions are correct
```

### Memory Issues
```bash
docker stats
# If containers use >1GB each, reduce concurrent containers
```

### Network Issues
```bash
docker exec -it CONTAINER_NAME ping google.com
# Check if container has internet access
```

## 🎯 Performance Benchmarks

### Expected Performance (per container)
- **Startup time**: < 10 seconds
- **Processing rate**: 1-2 URLs per second
- **Memory usage**: 300-600 MB
- **CPU usage**: 10-30%
- **Success rate**: > 80%

### Warning Signs
- ❌ Startup > 30 seconds
- ❌ Memory > 1GB per container
- ❌ CPU constantly > 80%
- ❌ Success rate < 50%

## 🚀 Production Readiness Checklist

- [ ] Single container test passes
- [ ] Multi-container test passes  
- [ ] No memory leaks after 1 hour
- [ ] No crashes under load
- [ ] Notifications working (if configured)
- [ ] S3 upload working (if configured)
- [ ] Can scale to 10+ containers per instance

## 📊 Multi-Instance Test

After single instance testing, test with 2-3 instances:

### Instance Configuration
- **Instance 1**: URLs 0-999 (containers 1-5)
- **Instance 2**: URLs 1000-1999 (containers 6-10)
- **Instance 3**: URLs 2000-2999 (containers 11-15)

### Commands
```bash
# Deploy to all instances
./deploy_via_git.sh https://github.com/wunderkinds07/ghost-protocol.git INSTANCE_1_IP
./deploy_via_git.sh https://github.com/wunderkinds07/ghost-protocol.git INSTANCE_2_IP  
./deploy_via_git.sh https://github.com/wunderkinds07/ghost-protocol.git INSTANCE_3_IP

# Scale on each instance
# (Run the container commands on each instance with different URL ranges)
```

### Multi-Instance Success Criteria
- [ ] All instances deploy successfully
- [ ] Containers start on all instances
- [ ] No URL overlap between instances
- [ ] Total processing rate > 10 URLs/second
- [ ] Can monitor all instances easily