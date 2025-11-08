#!/bin/bash
# Fixed Claude Desktop Launcher for Fedora Asahi - Version 2
# Addresses multiple mount issues and ARM64 graphics problems



# Configuration
APPIMAGE_DIR="/home/longne/Documents/claude-desktop-to-appimage"
LOCK_FILE="/tmp/claude-desktop.lock"
PID_FILE="$HOME/.cache/claude-desktop.pid"

# Function to find the latest AppImage in the directory
find_latest_appimage() {
    # First, try to find persistent AppImages
    local latest_persistent=$(find "$APPIMAGE_DIR" -maxdepth 1 -name "Claude_Desktop-*-aarch64-persistent.AppImage" -type f 2>/dev/null | sort -V | tail -n 1)

    # If persistent version exists, use it
    if [ -n "$latest_persistent" ] && [ -f "$latest_persistent" ]; then
        echo "$latest_persistent"
        return 0
    fi

    # Otherwise, find any Claude Desktop AppImage
    local latest_any=$(find "$APPIMAGE_DIR" -maxdepth 1 -name "Claude_Desktop-*-aarch64.AppImage" -type f 2>/dev/null | sort -V | tail -n 1)

    if [ -n "$latest_any" ] && [ -f "$latest_any" ]; then
        echo "$latest_any"
        return 0
    fi

    return 1
}

# Detect the latest AppImage
APPIMAGE_PATH=$(find_latest_appimage)

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

# Function to check for and update AppImage
check_and_update_appimage() {
    log_info "Checking for latest Claude Desktop AppImage..."

    local GITHUB_API_URL="https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest"
    local CURRENT_APPIMAGE_VERSION=""

    if [ -n "$APPIMAGE_PATH" ] && [ -f "$APPIMAGE_PATH" ]; then
        # Extract version from the existing AppImage filename
        # Expected format: Claude_Desktop-X.Y.Z-aarch64[-persistent].AppImage
        CURRENT_APPIMAGE_VERSION=$(basename "$APPIMAGE_PATH" | sed -n 's/Claude_Desktop-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-aarch64.*\.AppImage/\1/p')
        log_info "Current AppImage: $(basename "$APPIMAGE_PATH")"
        log_info "Current AppImage version: $CURRENT_APPIMAGE_VERSION"
    else
        log_warn "No existing AppImage found in $APPIMAGE_DIR. Will attempt to download the latest."
    fi

    # Check for curl and jq
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed. Please install it to enable automatic updates (e.g., sudo dnf install curl)."
        return 1
    fi
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it to enable automatic updates (e.g., sudo dnf install jq)."
        return 1
    fi

    local LATEST_RELEASE_INFO=$(curl -s "$GITHUB_API_URL")
    local LATEST_VERSION=$(echo "$LATEST_RELEASE_INFO" | jq -r '.tag_name' | sed 's/v//') # Remove 'v' prefix
    local DOWNLOAD_URL=$(echo "$LATEST_RELEASE_INFO" | jq -r '.assets[] | select(.name | contains("arm64.AppImage")) | .browser_download_url')

    if [ -z "$LATEST_VERSION" ] || [ -z "$DOWNLOAD_URL" ]; then
        log_error "Could not retrieve latest release information or download URL from GitHub."
        return 1
    fi

    log_info "Latest available version: $LATEST_VERSION"

    version_gt() {
    test "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" = "$2"
}

    if [ -z "$CURRENT_APPIMAGE_VERSION" ] || version_gt "$LATEST_VERSION" "$CURRENT_APPIMAGE_VERSION"; then
        log_info "Newer version available or no existing AppImage. Downloading $LATEST_VERSION..."
        local NEW_APPIMAGE_PATH="$APPIMAGE_DIR/Claude_Desktop-${LATEST_VERSION}-aarch64-persistent.AppImage"
        local TEMP_APPIMAGE="/tmp/Claude_Desktop-${LATEST_VERSION}-aarch64.AppImage"

        if curl -L -o "$TEMP_APPIMAGE" "$DOWNLOAD_URL"; then
            log_info "Download complete. Installing new AppImage..."
            mkdir -p "$APPIMAGE_DIR"
            mv "$TEMP_APPIMAGE" "$NEW_APPIMAGE_PATH"
            chmod +x "$NEW_APPIMAGE_PATH"
            log_info "AppImage installed to $NEW_APPIMAGE_PATH"

            # Update APPIMAGE_PATH to the new file
            APPIMAGE_PATH="$NEW_APPIMAGE_PATH"
        else
            log_error "Failed to download the new AppImage."
            return 1
        fi
    else
        log_info "You are already on the latest version ($CURRENT_APPIMAGE_VERSION)."
    fi
    return 0
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
    log_info "=== Claude Desktop Fixed Launcher v2 ===\n"
    log_info "For Fedora Asahi ARM64 systems\n"

    # Check and update AppImage before proceeding
    check_and_update_appimage

    # Re-detect AppImage path after potential update
    if [ -z "$APPIMAGE_PATH" ] || [ ! -f "$APPIMAGE_PATH" ]; then
        APPIMAGE_PATH=$(find_latest_appimage)
    fi

    # Check if AppImage exists after potential update
    if [ -z "$APPIMAGE_PATH" ] || [ ! -f "$APPIMAGE_PATH" ]; then
        log_error "AppImage not found in $APPIMAGE_DIR. Automatic update failed or no AppImage available."
        log_info "Please ensure an AppImage is present or check your internet connection and GitHub access."
        exit 1
    fi

    log_info "Using AppImage: $(basename "$APPIMAGE_PATH")"

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
