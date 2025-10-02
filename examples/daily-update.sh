#!/bin/bash

# Daily Homebrew Update Script
# This script demonstrates how to integrate brewup into your daily workflow

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📅 Daily System Update Script${NC}"
echo "================================="
echo ""

# Check if brewup is installed
if ! command -v brewup &> /dev/null; then
    echo -e "${YELLOW}⚠️  brewup is not installed or not in PATH${NC}"
    echo "Please install brewup first:"
    echo "  git clone <repo-url>"
    echo "  cd brewup"
    echo "  make install"
    echo ""
    echo "Or add ~/.local/bin to your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    exit 1
fi

echo -e "${GREEN}🍺 Running brewup...${NC}"
echo ""

# Run brewup with verbose output
# Remove --dry-run when you're ready to actually update
brewup --verbose

echo ""
echo -e "${GREEN}✅ Daily update completed!${NC}"
echo ""

# Optional: Show some system info
echo -e "${BLUE}📊 System Summary:${NC}"
echo "- Homebrew packages: $(brew list | wc -l | tr -d ' ') installed"
echo "- macOS version: $(sw_vers -productVersion)"
echo "- Date: $(date)"

# Optional: Clean up other caches
echo ""
echo -e "${BLUE}🧹 Additional cleanup (optional):${NC}"
echo "You might also want to run:"
echo "  - Clear npm cache: npm cache clean --force"
echo "  - Clear pip cache: pip cache purge"
echo "  - Clear Docker: docker system prune"
echo "  - Clear Xcode: xcrun simctl delete unavailable"
