#!/bin/bash
# Fixed Claude Desktop Launcher for Fedora Asahi - Version 2
# Addresses multiple mount issues and ARM64 graphics problems

set -e

# Configuration
APPIMAGE_PATH="/home/longne/Documents/GitHub/claude-desktop-to-appimage/Claude_Desktop-0.9.3-aarch64-persistent.AppImage"
LOCK_FILE="/tmp/claude-desktop.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to clean up existing Claude processes and mounts
cleanup_claude() {
    log_info "Cleaning up existing Claude processes and mounts..."
    
    # Kill existing Claude processes
    pkill -f claude-desktop 2>/dev/null || true
    pkill -f "Claude_Desktop.*AppImage" 2>/dev/null || true
    pkill -f "/tmp/.mount_claude" 2>/dev/null || true
    
    # Wait for processes to exit
    sleep 2
    
    # Clean up old AppImage mounts
    for mount in $(mount | grep -o '/tmp/\.mount_claude[^[:space:]]*' | sort -u); do
        if [ -d "$mount" ]; then
            log_info "Cleaning up mount: $mount"
            fusermount -u "$mount" 2>/dev/null || umount "$mount" 2>/dev/null || true
            sleep 1
        fi
    done
    
    # Remove old temporary files
    rm -rf /tmp/.mount_claude* 2>/dev/null || true
    rm -f "$LOCK_FILE" 2>/dev/null || true
}

# Function to set up environment for Fedora Asahi ARM64
setup_environment() {
    log_info "Setting up environment for Fedora Asahi ARM64..."
    
    # Graphics and display fixes for ARM64/Asahi
    export ELECTRON_OZONE_PLATFORM_HINT=auto
    export ELECTRON_DISABLE_SECURITY_WARNINGS=true
    export LIBGL_ALWAYS_SOFTWARE=1
    export MESA_GL_VERSION_OVERRIDE=3.3
    export DISPLAY="${DISPLAY:-:0}"
    
    # Memory optimization (FIXED: removed invalid --max-listeners option)
    export NODE_OPTIONS="--max-old-space-size=4096"
    
    # Single instance enforcement
    export ELECTRON_IS_DEV=false
    export ELECTRON_ENABLE_LOGGING=false
    
    # Data persistence directories
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    
    # Create data directories
    mkdir -p "$XDG_CONFIG_HOME/Claude"
    mkdir -p "$XDG_DATA_HOME/Claude"
    mkdir -p "$XDG_CACHE_HOME/Claude"
}

# Function to launch Claude Desktop
launch_claude() {
    log_info "Launching Claude Desktop..."
    
    # Launch with proper flags for Asahi Linux ARM64
    "$APPIMAGE_PATH" \
        --no-sandbox \
        --disable-gpu-sandbox \
        --disable-software-rasterizer \
        --disable-dev-shm-usage \
        --disable-extensions \
        --disable-plugins \
        --single-instance \
        --user-data-dir="$XDG_CONFIG_HOME/Claude" \
        "$@" 2>&1 | while IFS= read -r line; do
            # Filter out the EventEmitter warning we know about
            if [[ ! "$line" =~ "MaxListenersExceededWarning" ]]; then
                echo "$line"
            fi
        done
}

# Main execution
main() {
    log_info "=== Claude Desktop Fixed Launcher v2 ==="
    log_info "For Fedora Asahi ARM64 systems"
    echo
    
    # Check if AppImage exists
    if [ ! -f "$APPIMAGE_PATH" ]; then
        log_error "AppImage not found: $APPIMAGE_PATH"
        log_info "Available AppImages in directory:"
        ls -la /home/longne/Documents/GitHub/claude-desktop-to-appimage/Claude_Desktop-*.AppImage 2>/dev/null || log_error "No AppImages found"
        exit 1
    fi
    
    # Make AppImage executable
    chmod +x "$APPIMAGE_PATH"
    
    # Clean up any previous instances
    cleanup_claude
    
    # Set up environment
    setup_environment
    
    # Launch Claude
    launch_claude "$@"
}

# Handle signals for cleanup
trap cleanup_claude EXIT INT TERM

# Run main function
main "$@"
