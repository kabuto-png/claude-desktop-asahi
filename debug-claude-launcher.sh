#!/bin/bash

# Debug version of Claude Desktop Launcher
echo "DEBUG: Script started"
echo "DEBUG: Current directory: $(pwd)"
echo "DEBUG: Script path: $0"
echo "DEBUG: Arguments: $@"

# Configuration
APPIMAGE_PATH="/home/longne/Documents/GitHub/claude-desktop-to-appimage/Claude_Desktop-0.9.3-aarch64-persistent.AppImage"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "DEBUG: About to check AppImage existence"
if [ ! -f "$APPIMAGE_PATH" ]; then
    log_error "AppImage not found: $APPIMAGE_PATH"
    exit 1
fi

echo "DEBUG: AppImage exists, continuing..."
log_info "AppImage found: $APPIMAGE_PATH"
echo "DEBUG: Script completed successfully"
