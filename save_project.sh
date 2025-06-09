#!/bin/bash

echo "💾 Saving 1stDibs Extractor Project"
echo "==================================="

# Create timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SAVE_DIR="project_saves/save_$TIMESTAMP"

# Create save directory
mkdir -p "$SAVE_DIR"

# List of important files and directories to save
echo "📁 Creating project snapshot..."

# Copy all project files
cp -r src/ "$SAVE_DIR/"
cp -r docker/ "$SAVE_DIR/"
cp -r deployment/ "$SAVE_DIR/"
cp -r .github/ "$SAVE_DIR/" 2>/dev/null || true

# Copy all documentation
cp *.md "$SAVE_DIR/"
cp *.sh "$SAVE_DIR/"
cp *.py "$SAVE_DIR/" 2>/dev/null || true
cp *.html "$SAVE_DIR/" 2>/dev/null || true
cp .gitignore "$SAVE_DIR/"
cp requirements.txt "$SAVE_DIR/"

# Create project summary
cat > "$SAVE_DIR/PROJECT_STATE.md" << EOF
# Project Save - $TIMESTAMP

## Key Features Implemented

1. **Docker Containerization**
   - Each container processes 5,000 URLs
   - Creative naming system (phoenix, gallardo, nebula, etc.)
   - Automatic retries and error handling

2. **Notification System**
   - Default ntfy.sh topic: callofdutyblackopsghostprotocolbravo64
   - Support for Discord, Slack, Telegram, Pushover
   - Real-time progress updates

3. **Data Extraction**
   - Product information
   - Multi-currency pricing
   - Image URLs
   - Specifications and dimensions
   - Compressed HTML storage

4. **Deployment Options**
   - Local deployment script
   - Docker Compose configuration
   - Kubernetes manifests
   - Cloud-ready architecture

## File Structure
$(find . -type f -name "*.py" -o -name "*.sh" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" | grep -v node_modules | grep -v .git | sort)

## Configuration
- Default notification topic: callofdutyblackopsghostprotocolbravo64
- Monitor URL: https://ntfy.sh/callofdutyblackopsghostprotocolbravo64
- Container naming: 250+ creative names
- Chunk size: 5,000 URLs per container

## Quick Commands
- Test: ./test_local.sh
- Deploy: ./deployment/deploy_local.sh
- Monitor: open monitor.html
EOF

# Create restoration script
cat > "$SAVE_DIR/restore.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restoring project files..."
cp -r * ../ 2>/dev/null || true
echo "✅ Project restored!"
echo "📝 Don't forget to:"
echo "   - Check Docker is running"
echo "   - Review any environment-specific settings"
EOF
chmod +x "$SAVE_DIR/restore.sh"

# Create archive
echo "📦 Creating archive..."
tar -czf "project_saves/1stdibs_extractor_$TIMESTAMP.tar.gz" -C "$SAVE_DIR" .

# Git commit (if in git repo)
if [ -d .git ]; then
    echo "📝 Creating git commit..."
    git add -A
    git commit -m "Save project state - $TIMESTAMP

- Notification system with default ntfy topic
- Docker containerization with creative names
- Deployment scripts and monitoring
- Complete documentation

Topic: callofdutyblackopsghostprotocolbravo64" || true
fi

echo ""
echo "✅ Project saved successfully!"
echo ""
echo "📁 Save location: $SAVE_DIR"
echo "📦 Archive: project_saves/1stdibs_extractor_$TIMESTAMP.tar.gz"
echo ""
echo "🔗 Notification monitoring:"
echo "   https://ntfy.sh/callofdutyblackopsghostprotocolbravo64"
echo ""
echo "📊 Local monitoring dashboard:"
echo "   open monitor.html"
echo ""
echo "To restore from this save:"
echo "   cd $SAVE_DIR && ./restore.sh"