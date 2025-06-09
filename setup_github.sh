#!/bin/bash

echo "🚀 Setting up GitHub repository for 1stDibs Extractor"
echo "=================================================="

# Initialize git if not already
if [ ! -d .git ]; then
    git init
    echo "✅ Git repository initialized"
fi

# Add all files
git add .
echo "✅ Files staged"

# Create initial commit
git commit -m "Initial commit: 1stDibs extraction pipeline with named chunks

- Scalable Docker containerized architecture
- Creative chunk naming system (alpha, bravo, phoenix, etc.)
- Extracts product data and saves raw HTML
- Supports 5,000 URLs per container
- Deployment ready for Docker, Kubernetes, and cloud platforms"

echo "✅ Initial commit created"

# Instructions for GitHub
echo ""
echo "📝 Next steps to push to GitHub:"
echo "1. Create a new repository on GitHub (don't initialize with README)"
echo "2. Run these commands:"
echo ""
echo "   git remote add origin https://github.com/YOUR_USERNAME/1stdibs-extractor.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Your repository will be live at:"
echo "   https://github.com/YOUR_USERNAME/1stdibs-extractor"
echo ""
echo "4. To enable GitHub Actions for automatic Docker builds:"
echo "   - Go to Settings > Actions > General"
echo "   - Enable 'Read and write permissions' for GITHUB_TOKEN"