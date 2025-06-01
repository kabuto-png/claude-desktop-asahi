#!/bin/bash
set -e

# Claude Desktop AppImage Builder
# Universal build script for creating Claude Desktop AppImage on Linux

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration defaults
APPIMAGETOOL_PATH="/usr/local/bin/appimagetool"
BUNDLE_ELECTRON=0
CLAUDE_DOWNLOAD_URL="https://claude.ai/download"
ARCH=$(uname -m)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --appimagetool <path>         Path to appimagetool (default: $APPIMAGETOOL_PATH)
  --bundle-electron             Bundle Electron with the AppImage (default: $BUNDLE_ELECTRON)
  --claude-download-url <url>   URL to download Claude installer (default: $CLAUDE_DOWNLOAD_URL)
  -h, --help                   Show this help message

Examples:
  $0                           # Build with default settings
  $0 --bundle-electron         # Bundle Electron with AppImage
  $0 --appimagetool ~/tools/appimagetool.AppImage

Architecture Detection:
  This script automatically detects your architecture ($ARCH) and calls the appropriate 
  build script. Supported architectures: x86_64, aarch64

Build Scripts Used:
  - Fedora Asahi (aarch64): fedora_asahi_build_script.sh
  - Manual builder: manual_appimage_builder.sh
  - Rebuild/fix: rebuild_and_fix.sh

EOF
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for Node.js
    if ! command -v node &> /dev/null; then
        missing_deps+=("nodejs")
    fi
    
    # Check for npm
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
    fi
    
    # Check for unzip
    if ! command -v unzip &> /dev/null; then
        missing_deps+=("unzip")
    fi
    
    # Check for wget or curl
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        missing_deps+=("wget or curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install them and try again."
        
        # Provide installation hints based on distro
        if command -v apt &> /dev/null; then
            log_info "On Debian/Ubuntu: sudo apt install nodejs npm unzip wget"
        elif command -v dnf &> /dev/null; then
            log_info "On Fedora: sudo dnf install nodejs npm unzip wget"
        elif command -v pacman &> /dev/null; then
            log_info "On Arch: sudo pacman -S nodejs npm unzip wget"
        fi
        
        exit 1
    fi
    
    log_success "All dependencies found"
}

detect_build_script() {
    local build_script=""
    
    # Check if we're on Fedora Asahi
    if grep -q "Fedora Linux Asahi" /etc/os-release 2>/dev/null && [ "$ARCH" = "aarch64" ]; then
        build_script="fedora_asahi_build_script.sh"
        log_info "Detected Fedora Asahi ARM64 - using optimized build script"
    # Check for other ARM64 systems
    elif [ "$ARCH" = "aarch64" ]; then
        build_script="manual_appimage_builder.sh"
        log_info "Detected ARM64 system - using manual builder"
    # Default for x86_64 and others
    else
        build_script="manual_appimage_builder.sh"
        log_info "Using manual AppImage builder for $ARCH"
    fi
    
    if [ ! -f "$SCRIPT_DIR/$build_script" ]; then
        log_error "Build script not found: $build_script"
        exit 1
    fi
    
    echo "$build_script"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --appimagetool)
            APPIMAGETOOL_PATH="$2"
            shift 2
            ;;
        --bundle-electron)
            BUNDLE_ELECTRON=1
            shift
            ;;
        --claude-download-url)
            CLAUDE_DOWNLOAD_URL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
log_info "Claude Desktop AppImage Builder"
log_info "Architecture: $ARCH"
log_info "Working directory: $SCRIPT_DIR"

# Check dependencies
check_dependencies

# Install npm dependencies if needed
if [ -f "$SCRIPT_DIR/package.json" ] && [ ! -d "$SCRIPT_DIR/node_modules" ]; then
    log_info "Installing npm dependencies..."
    cd "$SCRIPT_DIR"
    npm install
    log_success "npm dependencies installed"
fi

# Detect and run the appropriate build script
BUILD_SCRIPT=$(detect_build_script)
log_info "Using build script: $BUILD_SCRIPT"

# Prepare arguments for the build script
BUILD_ARGS=()
if [ "$BUNDLE_ELECTRON" = "1" ]; then
    BUILD_ARGS+=("--bundle-electron")
fi
if [ "$CLAUDE_DOWNLOAD_URL" != "https://claude.ai/download" ]; then
    BUILD_ARGS+=("--claude-download-url" "$CLAUDE_DOWNLOAD_URL")
fi
if [ "$APPIMAGETOOL_PATH" != "/usr/local/bin/appimagetool" ]; then
    BUILD_ARGS+=("--appimagetool" "$APPIMAGETOOL_PATH")
fi

# Execute the build script
log_info "Starting build process..."
cd "$SCRIPT_DIR"
chmod +x "$BUILD_SCRIPT"
./"$BUILD_SCRIPT" "${BUILD_ARGS[@]}"

log_success "Build completed! Check the current directory for the generated AppImage."
