#!/bin/bash
# Setup GitHub repository connection

GITHUB_URL=${1:-""}
if [ -z "$GITHUB_URL" ]; then
    echo "Usage: ./setup_github_repo.sh https://github.com/YOURUSERNAME/1stdibs-extractor.git"
    echo ""
    echo "Steps to get your GitHub URL:"
    echo "1. Go to github.com"
    echo "2. Click 'New repository'"
    echo "3. Name it '1stdibs-extractor'"
    echo "4. Create repository"
    echo "5. Copy the HTTPS URL from the page"
    exit 1
fi

echo "🐙 Setting up GitHub repository..."
echo "Repository: $GITHUB_URL"

# Add remote origin
git remote add origin "$GITHUB_URL"

# Push to GitHub
echo "📤 Pushing to GitHub..."
git push -u origin development

echo "✅ Repository setup complete!"
echo ""
echo "🔗 Your repository is now at: $GITHUB_URL"
echo ""
echo "🚀 Deploy to instances with:"
echo "./deploy_via_git.sh $GITHUB_URL INSTANCE_IP_1"
echo "./deploy_via_git.sh $GITHUB_URL INSTANCE_IP_2"
echo "./deploy_via_git.sh $GITHUB_URL INSTANCE_IP_3"