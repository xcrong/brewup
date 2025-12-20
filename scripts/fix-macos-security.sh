#!/usr/bin/env bash
set -euo pipefail

# BrewUp macOS Security Helper Script
# This script helps resolve macOS security issues with pre-built binaries

BINARY_NAME="brewup"
INSTALL_DIR="${HOME}/.local/bin"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
}

# Check if binary exists
check_binary() {
    if [ ! -f "$BINARY_PATH" ]; then
        log_error "Binary not found at: $BINARY_PATH"
        log_info "Please install brewup first using the install.sh script"
        exit 1
    fi
}

# Remove quarantine attribute
remove_quarantine() {
    log_step "Removing quarantine attribute..."
    
    if command -v xattr >/dev/null 2>&1; then
        if xattr -p com.apple.quarantine "$BINARY_PATH" >/dev/null 2>&1; then
            log_info "Found quarantine attribute, removing..."
            xattr -dr com.apple.quarantine "$BINARY_PATH"
            log_info "Quarantine attribute removed successfully"
        else
            log_info "No quarantine attribute found"
        fi
    else
        log_warn "xattr command not found, skipping quarantine removal"
    fi
}

# Attempt to sign the binary
sign_binary() {
    log_step "Attempting to sign the binary..."
    
    if command -v codesign >/dev/null 2>&1; then
        log_info "Signing binary with ad-hoc signature..."
        if codesign --sign - "$BINARY_PATH" 2>/dev/null; then
            log_info "Binary signed successfully"
        else
            log_warn "Could not sign binary (this is usually not critical)"
        fi
    else
        log_warn "codesign command not found, skipping signing"
    fi
}

# Check Gatekeeper status
check_gatekeeper() {
    log_step "Checking Gatekeeper status..."
    
    if command -v spctl >/dev/null 2>&1; then
        log_info "Checking if binary is allowed by Gatekeeper..."
        if spctl --assess --type exec "$BINARY_PATH" >/dev/null 2>&1; then
            log_info "Binary is allowed by Gatekeeper"
        else
            log_warn "Binary is blocked by Gatekeeper"
            log_warn "You have several options:"
            log_warn "1. Allow the app in System Preferences > Security & Privacy > General"
            log_warn "2. Right-click the binary and select 'Open' from the context menu"
            log_warn "3. Run: sudo spctl --master-disable (disables Gatekeeper globally - NOT recommended)"
            log_warn "4. Run: sudo xattr -dr com.apple.quarantine $BINARY_PATH (if not already done)"
        fi
    else
        log_warn "spctl command not found, skipping Gatekeeper check"
    fi
}

# Verify binary can be executed
verify_execution() {
    log_step "Verifying binary execution..."
    
    if "$BINARY_PATH" --version >/dev/null 2>&1; then
        log_info "✅ Binary can be executed successfully!"
        return 0
    else
        log_error "❌ Binary still cannot be executed"
        return 1
    fi
}

# Show manual steps if needed
show_manual_steps() {
    log_step "Manual steps if issues persist:"
    echo
    echo "1. Open System Preferences > Security & Privacy > General"
    echo "2. Look for a message about 'brewup' being blocked"
    echo "3. Click 'Allow Anyway' or 'Open Anyway'"
    echo
    echo "Alternative commands:"
    echo "  sudo xattr -dr com.apple.quarantine $BINARY_PATH"
    echo "  sudo codesign --force --sign - $BINARY_PATH"
    echo
    echo "To check current attributes:"
    echo "  xattr -l $BINARY_PATH"
    echo
}

# Main function
main() {
    log_info "BrewUp macOS Security Helper"
    log_info "=============================="
    
    check_macos
    check_binary
    
    remove_quarantine
    sign_binary
    check_gatekeeper
    
    if verify_execution; then
        log_info "=============================="
        log_info "✅ Security issues resolved successfully!"
        log_info "You can now use brewup normally"
    else
        log_warn "=============================="
        log_warn "⚠️  Some issues may still persist"
        show_manual_steps
    fi
}

# Run main function
main "$@"