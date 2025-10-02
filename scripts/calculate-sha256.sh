#!/bin/bash

# Script to calculate SHA256 hashes for Homebrew formula
# Usage: ./scripts/calculate-sha256.sh <version>

set -e

VERSION=${1:-"0.1.0"}
BASE_URL="https://github.com/xcrong/brewup/releases/download/v${VERSION}"

echo "🔍 Calculating SHA256 hashes for version ${VERSION}"
echo "=================================================="
echo ""

# Check if we have the release files locally
if [ ! -f "brewup-x86_64-apple-darwin.tar.gz" ]; then
    echo "📥 Downloading release files..."

    # Download the release files
    curl -L -o brewup-x86_64-apple-darwin.tar.gz "${BASE_URL}/brewup-x86_64-apple-darwin.tar.gz"
    curl -L -o brewup-aarch64-apple-darwin.tar.gz "${BASE_URL}/brewup-aarch64-apple-darwin.tar.gz"
    curl -L -o brewup-x86_64-unknown-linux-gnu.tar.gz "${BASE_URL}/brewup-x86_64-unknown-linux-gnu.tar.gz"
fi

echo ""
echo "🔢 SHA256 Hashes:"
echo "================="

# Calculate SHA256 for each file
echo "x86_64-apple-darwin:"
sha256sum brewup-x86_64-apple-darwin.tar.gz | cut -d' ' -f1

echo ""
echo "aarch64-apple-darwin:"
sha256sum brewup-aarch64-apple-darwin.tar.gz | cut -d' ' -f1

echo ""
echo "x86_64-unknown-linux-gnu:"
sha256sum brewup-x86_64-unknown-linux-gnu.tar.gz | cut -d' ' -f1

echo ""
echo "📝 Update your Formula/brewup.rb with these hashes:"
echo "==================================================="
echo "Replace the SHA256 values in the formula file with the values above."
echo ""
echo "For Intel Macs:"
echo "  sha256 \"$(sha256sum brewup-x86_64-apple-darwin.tar.gz | cut -d' ' -f1)\""
echo ""
echo "For Apple Silicon Macs:"
echo "  sha256 \"$(sha256sum brewup-aarch64-apple-darwin.tar.gz | cut -d' ' -f1)\""

# Clean up downloaded files
echo ""
echo "🧹 Cleaning up downloaded files..."
rm -f brewup-*.tar.gz

echo ""
echo "✅ Done!"
