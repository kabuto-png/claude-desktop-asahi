#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

# Claude Desktop Launcher (No Auto-Update)
# Launches the Claude Desktop AppImage without checking for updates.

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
APPIMAGE_PATH=$(/usr/bin/find "$PROJECT_DIR" -maxdepth 1 -name "Claude_Desktop-*-aarch64*.AppImage" -type f 2>/dev/null | sort -V | tail -n 1)
LOCK_FILE="/tmp/claude-desktop.lock"
PID_FILE="$HOME/.cache/claude-desktop.pid"

# Trap signals to cleanup on exit
trap 'cleanup_on_exit' EXIT INT TERM

# Cleanup function for script exit
cleanup_on_exit() {
    log_info "Script interrupted - cleaning up..."
    # Don't kill Claude Desktop when launcher script exits normally
    # Only cleanup temp files
    rm -f "$LOCK_FILE" 2>/dev/null || true
}

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

    # Kill all Claude Desktop processes more aggressively
    # 1. Kill by AppImage name pattern
    pkill -f "Claude_Desktop.*AppImage" 2>/dev/null || true
    
    # 2. Kill by electron process with Claude data directory
    pkill -f "user-data-dir.*Claude" 2>/dev/null || true
    
    # 3. Kill by mount point pattern
    pkill -f "/tmp/.mount_[Cc]laude" 2>/dev/null || true
    
    # 4. Kill by specific electron processes
    for pid in $(pgrep -f "electron.*Claude"); do
        if [ -n "$pid" ]; then
            log_info "Killing Claude process: $pid"
            kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
        fi
    done

    # Wait for processes to exit gracefully
    sleep 3

    # Force kill any remaining processes
    for pid in $(pgrep -f "Claude_Desktop\|/tmp/\.mount_[Cc]laude"); do
        if [ -n "$pid" ]; then
            log_warn "Force killing stubborn process: $pid"
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done

    # Clean up old AppImage mounts
    for mount in $(mount | grep -o '/tmp/\.mount_[Cc]laude[^[:space:]]*' | sort -u); do
        if [ -d "$mount" ]; then
            log_info "Cleaning up mount: $mount"
            fusermount -u "$mount" 2>/dev/null || umount "$mount" 2>/dev/null || true
            sleep 1
        fi
    done

    # Remove old temporary files
    rm -rf /tmp/.mount_[Cc]laude* 2>/dev/null || true
    rm -f "$LOCK_FILE" 2>/dev/null || true
    
    # Remove PID file if exists
    rm -f "$HOME/.cache/claude-desktop.pid" 2>/dev/null || true
    
    log_info "Cleanup completed."
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

    # Memory optimization
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

    # Check if already running by PID file
    PID_FILE="$HOME/.cache/claude-desktop.pid"
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            log_warn "Claude Desktop already running with PID: $OLD_PID"
            log_info "Killing existing instance..."
            kill -TERM "$OLD_PID" 2>/dev/null || kill -KILL "$OLD_PID" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$PID_FILE"
    fi

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
        "$@" > "$HOME/.cache/claude-desktop-launch.log" 2>&1 &
    
    # Save PID for later cleanup
    CLAUDE_PID=$!
    echo "$CLAUDE_PID" > "$PID_FILE"
    log_info "Claude Desktop launched with PID: $CLAUDE_PID"
    log_info "Log file: $HOME/.cache/claude-desktop-launch.log"
    
    disown
}

# Main execution
main() {
    log_info "=== Claude Desktop Launcher (No Auto-Update) ===\n"
    log_info "For Fedora Asahi ARM64 systems\n"

    # Check if AppImage exists
    if [ ! -f "$APPIMAGE_PATH" ]; then
        log_error "AppImage not found: $APPIMAGE_PATH. Please ensure the AppImage is present."
        exit 1
    fi

    # Make AppImage executable (redundant if updated, but safe)
    chmod +x "$APPIMAGE_PATH"

    # Clean up any previous instances
    cleanup_claude

    # Set up environment
    setup_environment

    # Launch Claude
    launch_claude "$@"
}

# Run main function
main "$@"
