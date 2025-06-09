#!/bin/bash

echo "GitHub Push Helper for swordsandshields2"
echo "========================================"
echo ""

# Check if remote exists
if git remote | grep -q "origin"; then
    echo "✓ Remote 'origin' already exists"
else
    echo "❌ No remote configured yet"
    echo ""
    echo "Please add your GitHub remote:"
    echo "  git remote add origin https://github.com/YOUR_USERNAME/swordsandshields2.git"
    echo ""
    echo "Or if using SSH:"
    echo "  git remote add origin git@github.com:YOUR_USERNAME/swordsandshields2.git"
    echo ""
    exit 1
fi

echo ""
echo "⚠️  WARNING: This repository contains large files"
echo ""
echo "Files over 100MB (GitHub's limit):"
find . -type f -size +100M | grep -v ".git" | grep -v "venv" | head -10
echo ""

echo "Options:"
echo "1. Use Git LFS (Large File Storage) - Recommended"
echo "2. Exclude large files from the repository"
echo "3. Push anyway (will fail for files >100MB)"
echo ""
read -p "Choose option (1-3): " option

case $option in
    1)
        echo ""
        echo "Setting up Git LFS..."
        
        # Check if git-lfs is installed
        if ! command -v git-lfs &> /dev/null; then
            echo "❌ Git LFS is not installed"
            echo "Install it first:"
            echo "  brew install git-lfs  # macOS"
            echo "  sudo apt-get install git-lfs  # Ubuntu/Debian"
            exit 1
        fi
        
        # Initialize Git LFS
        git lfs install
        
        # Track large files
        echo "Tracking large files with Git LFS..."
        git lfs track "*.txt" "*.csv" "*.json" "*.parquet"
        git add .gitattributes
        git commit -m "Add Git LFS tracking for large files"
        
        # Convert existing files to LFS
        git lfs migrate import --include="*.txt,*.csv,*.json,*.parquet" --include-ref=main
        
        echo "✓ Git LFS configured"
        echo ""
        echo "Now pushing to GitHub..."
        git push -u origin main
        ;;
        
    2)
        echo ""
        echo "Adding large files to .gitignore..."
        echo "" >> .gitignore
        echo "# Large files" >> .gitignore
        echo "data/raw/1m-urls-1stdibs-raw.txt" >> .gitignore
        echo "data/training/*.csv" >> .gitignore
        echo "data/training/*.json" >> .gitignore
        echo "data/training/*.parquet" >> .gitignore
        echo "data/reports/chunked/*.json" >> .gitignore
        echo "deployment/raw/*.txt" >> .gitignore
        echo "1m-urls-1stdibs-raw.txt" >> .gitignore
        
        git add .gitignore
        git commit -m "Exclude large files from repository"
        
        # Remove large files from git history
        echo "Removing large files from git history..."
        git filter-branch --force --index-filter \
            'git rm --cached --ignore-unmatch data/raw/1m-urls-1stdibs-raw.txt \
             data/training/*.csv data/training/*.json data/training/*.parquet \
             data/reports/chunked/*.json deployment/raw/*.txt 1m-urls-1stdibs-raw.txt' \
            --prune-empty --tag-name-filter cat -- --all
        
        echo "✓ Large files excluded"
        echo ""
        echo "Now pushing to GitHub..."
        git push -u origin main --force
        ;;
        
    3)
        echo ""
        echo "Attempting to push (this will likely fail)..."
        echo "Increasing buffer size..."
        git config http.postBuffer 524288000
        git push -u origin main
        ;;
esac

echo ""
echo "Done!"