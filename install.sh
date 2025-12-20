#!/usr/bin/env bash
set -euo pipefail

# BrewUp Installation Script
# Usage: curl -sSL https://raw.githubusercontent.com/xcrong/brewup/main/install.sh | sh

REPO="xcrong/brewup"
GITHUB_API_URL="https://api.github.com/repos/${REPO}/releases/latest"
INSTALL_DIR="${HOME}/.local/bin"
BINARY_NAME="brewup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Detect OS and architecture
detect_platform() {
    local os arch platform
    
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    
    case "$os" in
        linux)
            platform="linux"
            ;;
        darwin)
            platform="apple-darwin"
            ;;
        *)
            log_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        aarch64|arm64)
            arch="aarch64"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    echo "${arch}-${platform}"
}

# Get latest release information
get_latest_release() {
    log_info "Fetching latest release information..."
    
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed. Please install curl and try again."
        exit 1
    fi
    
    local release_info
    release_info=$(curl -sSL "$GITHUB_API_URL")
    
    if echo "$release_info" | grep -q '"tag_name"'; then
        echo "$release_info"
    else
        log_error "Failed to fetch release information. Please check your internet connection and try again."
        exit 1
    fi
}

# Extract download URL for the platform
get_download_url() {
    local release_info platform
    release_info="$1"
    platform="$2"
    
    local asset_name="brewup-${platform}.tar.gz"
    local download_url
    
    download_url=$(echo "$release_info" | grep -o "\"browser_download_url\": \"[^\"]*${asset_name}\"" | cut -d'"' -f4)
    
    if [ -z "$download_url" ]; then
        log_error "No binary found for platform: $platform"
        exit 1
    fi
    
    echo "$download_url"
}

# Download and extract binary
download_binary() {
    local download_url temp_dir binary_path
    download_url="$1"
    temp_dir=$(mktemp -d)
    
    log_info "Downloading brewup binary..."
    
    if ! curl -sSL "$download_url" -o "${temp_dir}/brewup.tar.gz" 2>/dev/null; then
        log_error "Failed to download binary"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_info "Extracting binary..."
    if ! tar -xzf "${temp_dir}/brewup.tar.gz" -C "$temp_dir" 2>/dev/null; then
        log_error "Failed to extract binary"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    binary_path="${temp_dir}/brewup"
    if [ ! -f "$binary_path" ]; then
        log_error "Binary not found in archive"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_info "Binary extracted successfully"
    
    # Return only the path to stdout, no other output
    printf "%s" "$binary_path"
}

# Install binary
install_binary() {
    local binary_path temp_dir
    binary_path="$1"
    temp_dir=$(dirname "$binary_path")
    
    # Create install directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR" ]; then
        log_info "Creating installation directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi
    
    # Install binary
    log_info "Installing brewup to $INSTALL_DIR/$BINARY_NAME"
    if ! cp "$binary_path" "$INSTALL_DIR/$BINARY_NAME"; then
        log_error "Failed to install binary"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Make binary executable
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    
    # Clean up temp directory
    rm -rf "$temp_dir"
}

# Handle macOS security issues
handle_macos_security() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "Handling macOS security settings..."
        
        # Remove quarantine attribute
        if command -v xattr >/dev/null 2>&1; then
            xattr -dr com.apple.quarantine "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null || true
        fi
        
        # Try to sign the binary (if codesign is available)
        if command -v codesign >/dev/null 2>&1; then
            log_info "Attempting to sign the binary..."
            codesign --sign - "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null || log_warn "Could not sign binary, but installation completed"
        fi
        
        log_warn "On macOS, you may need to allow the app in System Preferences > Security & Privacy"
        log_warn "If you encounter 'brewup cannot be opened' errors, run: sudo spctl --master-disable"
    fi
}

# Detect current shell
detect_shell() {
    if [ -n "${SHELL:-}" ]; then
        echo "$SHELL" | sed 's|.*/||'
    elif [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        # Fallback detection
        ps -p $$ | tail -n 1 | awk '{print $4}' | sed 's|.*/||'
    fi
}

# Get shell configuration file
get_shell_config() {
    local shell_type="$1"
    local home_dir="$HOME"
    
    case "$shell_type" in
        bash)
            if [ -f "$home_dir/.bashrc" ]; then
                echo "$home_dir/.bashrc"
            elif [ -f "$home_dir/.bash_profile" ]; then
                echo "$home_dir/.bash_profile"
            else
                echo "$home_dir/.bashrc"
            fi
            ;;
        zsh)
            echo "$home_dir/.zshrc"
            ;;
        fish)
            echo "$home_dir/.config/fish/config.fish"
            ;;
        *)
            echo "$home_dir/.${shell_type}rc"
            ;;
    esac
}

# Add PATH to shell configuration
add_to_path() {
    local shell_type shell_config path_export
    shell_type=$(detect_shell)
    shell_config=$(get_shell_config "$shell_type")
    path_export="export PATH=\"\$PATH:$INSTALL_DIR\""
    
    log_info "Detected shell: $shell_type"
    log_info "Shell configuration file: $shell_config"
    
    # Check if PATH export already exists
    if [ -f "$shell_config" ] && grep -q "export.*PATH.*$INSTALL_DIR" "$shell_config"; then
        log_info "PATH already configured in $shell_config"
        return 0
    fi
    
    # Ask user for confirmation
    echo
    log_warn "$INSTALL_DIR is not in your PATH"
    log_info "Would you like to add it to your PATH automatically? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Adding PATH export to $shell_config..."
        
        # Create backup
        if [ -f "$shell_config" ]; then
            cp "$shell_config" "${shell_config}.bak"
            log_info "Created backup: ${shell_config}.bak"
        fi
        
        # Add PATH export
        {
            echo ""
            echo "# BrewUp installation directory"
            echo "$path_export"
        } >> "$shell_config"
        
        log_info "✅ PATH export added to $shell_config"
        log_info "Please run: source $shell_config"
        log_info "Or restart your terminal to use brewup immediately"
        
        return 0
    else
        log_info "You can manually add the following to $shell_config:"
        log_info "$path_export"
        return 1
    fi
}

# Check if binary is in PATH
check_path() {
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        add_to_path
        return $?
    fi
    log_info "$INSTALL_DIR is already in your PATH"
    return 0
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check if binary exists and is executable
    if [ ! -x "$INSTALL_DIR/$BINARY_NAME" ]; then
        log_error "Binary not found or not executable at $INSTALL_DIR/$BINARY_NAME"
        return 1
    fi
    
    # Check if binary produces version output (ignoring exit code)
    local version_output
    version_output=$("$INSTALL_DIR/$BINARY_NAME" --version 2>&1 || true)
    
    if [ -z "$version_output" ] || [[ "$version_output" != *"brewup"* ]]; then
        log_error "Installation verification failed - no valid version output"
        return 1
    fi
    
    log_info "Installation successful!"
    log_info "Run 'brewup --help' to get started"
    return 0
}

# Main installation function
main() {
    log_info "BrewUp Installation Script"
    log_info "=============================="
    
    # Detect platform
    local platform
    platform=$(detect_platform)
    log_info "Detected platform: $platform"
    
    # Get latest release
    local release_info
    release_info=$(get_latest_release)
    
    local tag_name
    tag_name=$(echo "$release_info" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    log_info "Latest version: $tag_name"
    
    # Get download URL
    local download_url
    download_url=$(get_download_url "$release_info" "$platform")
    log_info "Download URL: $download_url"
    
    # Download and install
    local binary_path
    binary_path=$(download_binary "$download_url")
    install_binary "$binary_path"
    
    # Handle macOS security
    handle_macos_security
    
    # Check PATH
    check_path
    
    # Verify installation
    verify_installation
    
    log_info "=============================="
    log_info "BrewUp has been successfully installed!"
    log_info "Enjoy automating your Homebrew package management 🍺"
}

# Run main function
main "$@"