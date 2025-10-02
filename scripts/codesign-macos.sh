#!/bin/bash

# BrewUp macOS Code Signing Script
# This script helps with code signing for macOS binaries to avoid Gatekeeper warnings

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo -e "${BLUE}"
echo "🍺 BrewUp macOS Code Signing Helper"
echo "===================================="
echo -e "${NC}"

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is for macOS only."
    exit 1
fi

BINARY_PATH="$1"

if [[ -z "$BINARY_PATH" ]]; then
    print_info "Usage: $0 <path-to-brewup-binary>"
    print_info "Example: $0 brewup"
    print_info "Example: $0 target/release/brewup"
    echo ""
    print_info "Available options:"
    print_info "  --help          Show this help message"
    print_info "  --remove-xattr  Remove quarantine attributes only"
    print_info "  --adhoc-sign    Create ad-hoc signature (no certificate required)"
    exit 1
fi

if [[ "$BINARY_PATH" == "--help" ]]; then
    print_info "BrewUp macOS Code Signing Helper"
    echo ""
    print_info "This script helps resolve macOS Gatekeeper warnings when running"
    print_info "downloaded binaries from GitHub releases."
    echo ""
    print_info "Options:"
    print_info "  --remove-xattr    Remove quarantine attributes (quick fix)"
    print_info "  --adhoc-sign      Create ad-hoc code signature"
    print_info "  <binary-path>     Process the specified binary"
    echo ""
    print_info "For Homebrew users, the recommended approach is to install via:"
    print_info "  brew tap xcrong/brewup && brew install brewup"
    exit 0
fi

if [[ "$BINARY_PATH" == "--remove-xattr" ]]; then
    print_info "Looking for brewup binary in common locations..."

    # Try to find the binary
    if [[ -f "brewup" ]]; then
        BINARY_PATH="brewup"
    elif [[ -f "target/release/brewup" ]]; then
        BINARY_PATH="target/release/brewup"
    elif command -v brewup &> /dev/null; then
        BINARY_PATH=$(which brewup)
    else
        print_error "Could not find brewup binary. Please specify the path."
        exit 1
    fi
fi

if [[ ! -f "$BINARY_PATH" ]]; then
    print_error "Binary not found: $BINARY_PATH"
    exit 1
fi

print_info "Processing binary: $BINARY_PATH"

# Check current file attributes
print_info "Checking current file attributes..."
xattr -l "$BINARY_PATH" 2>/dev/null || print_info "No extended attributes found"

# Remove quarantine attribute (if present)
print_info "Removing quarantine attributes..."
xattr -dr com.apple.quarantine "$BINARY_PATH" 2>/dev/null || true
xattr -c "$BINARY_PATH" 2>/dev/null || true

# Ensure executable permissions
print_info "Setting executable permissions..."
chmod +x "$BINARY_PATH"

if [[ "$1" == "--adhoc-sign" ]] || [[ "$2" == "--adhoc-sign" ]]; then
    print_info "Creating ad-hoc code signature..."

    # Check if codesign is available
    if ! command -v codesign &> /dev/null; then
        print_error "codesign command not found. This requires Xcode command line tools."
        print_info "Install with: xcode-select --install"
        exit 1
    fi

    # Create ad-hoc signature (doesn't require Apple Developer account)
    codesign --force --verbose=4 --sign - "$BINARY_PATH"

    # Verify the signature
    print_info "Verifying code signature..."
    codesign --verify --verbose=4 "$BINARY_PATH" || {
        print_warning "Ad-hoc signature verification failed, but binary should still work"
    }
fi

print_success "Binary preparation complete: $BINARY_PATH"
echo ""

print_info "You can now run:"
print_info "  $BINARY_PATH --version"

echo ""
print_warning "Note: For distribution, consider:"
print_warning "1. Using Homebrew (recommended for users)"
print_warning "2. Getting an Apple Developer certificate for proper signing"
print_warning "3. Using GitHub Actions with proper code signing"

# Test the binary
if [[ -x "$BINARY_PATH" ]]; then
    print_info "Testing binary..."
    if "$BINARY_PATH" --version &>/dev/null; then
        print_success "Binary test passed!"
    else
        print_warning "Binary test failed, but it may still work with proper execution"
    fi
fi
