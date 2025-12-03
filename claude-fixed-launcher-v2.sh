#!/bin/bash
# Fixed Claude Desktop Launcher for Fedora Asahi - Version 2
# Addresses multiple mount issues and ARM64 graphics problems



# Configuration
APPIMAGE_DIR="/home/longne/Documents/claude-desktop-to-appimage"
LOCK_FILE="/tmp/claude-desktop.lock"
PID_FILE="$HOME/.cache/claude-desktop.pid"
UPDATE_CHECK_FILE="$HOME/.cache/claude-desktop-update-check"
UPDATE_CHECK_INTERVAL=$((30 * 24 * 60 * 60))  # 30 days in seconds
DISABLE_UPDATE_CHECK=true  # Set to true to disable automatic update checks (useful for local builds)

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

# Function to check if update check is needed
should_check_for_updates() {
    # If no AppImage exists, always check
    if [ -z "$APPIMAGE_PATH" ] || [ ! -f "$APPIMAGE_PATH" ]; then
        return 0
    fi

    # If update check file doesn't exist, check
    if [ ! -f "$UPDATE_CHECK_FILE" ]; then
        return 0
    fi

    # Check if enough time has passed since last check
    local LAST_CHECK=$(cat "$UPDATE_CHECK_FILE" 2>/dev/null || echo "0")
    local CURRENT_TIME=$(date +%s)
    local TIME_DIFF=$((CURRENT_TIME - LAST_CHECK))

    if [ $TIME_DIFF -ge $UPDATE_CHECK_INTERVAL ]; then
        return 0
    fi

    return 1
}

# Function to check for and update AppImage
check_and_update_appimage() {
    # Skip if update check is disabled
    if [ "$DISABLE_UPDATE_CHECK" = true ]; then
        return 0
    fi

    # Skip update check if not needed
    if ! should_check_for_updates; then
        return 0
    fi

    log_info "Checking for updates (last checked: $([ -f "$UPDATE_CHECK_FILE" ] && date -d @$(cat "$UPDATE_CHECK_FILE") '+%Y-%m-%d' || echo 'never'))..."

    local GITHUB_API_URL="https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest"
    local CURRENT_APPIMAGE_VERSION=""

    if [ -n "$APPIMAGE_PATH" ] && [ -f "$APPIMAGE_PATH" ]; then
        # Extract version from the existing AppImage filename
        # Expected format: Claude_Desktop-X.Y.Z[.W]-aarch64[-persistent].AppImage
        # Supports both 3-part (0.14.10) and 4-part (1.0.1307) versions
        CURRENT_APPIMAGE_VERSION=$(basename "$APPIMAGE_PATH" | sed -n 's/Claude_Desktop-\([0-9]\+\.[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?\)-aarch64.*\.AppImage/\1/p')
    fi

    # Check for required tools
    if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
        # Silently skip update check if tools are missing
        return 0
    fi

    # Fetch latest release info
    local LATEST_RELEASE_INFO=$(curl -s "$GITHUB_API_URL" 2>/dev/null)
    if [ -z "$LATEST_RELEASE_INFO" ]; then
        # Silently skip if GitHub is unreachable
        return 0
    fi

    # Extract the actual Claude Desktop version from the asset filename
    local ASSET_NAME=$(echo "$LATEST_RELEASE_INFO" | jq -r '.assets[] | select(.name | contains("arm64.AppImage") and (contains("arm64.AppImage.zsync") | not)) | .name' 2>/dev/null | head -1)
    local DOWNLOAD_URL=$(echo "$LATEST_RELEASE_INFO" | jq -r '.assets[] | select(.name | contains("arm64.AppImage") and (contains("arm64.AppImage.zsync") | not)) | .browser_download_url' 2>/dev/null | head -1)
    # Support both 3-part and 4-part version numbers
    local LATEST_VERSION=$(echo "$ASSET_NAME" | sed -n 's/claude-desktop-\([0-9]\+\.[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?\)-arm64\.AppImage/\1/p')

    if [ -z "$LATEST_VERSION" ] || [ -z "$DOWNLOAD_URL" ]; then
        # Silently skip if we can't parse the response
        return 0
    fi

    # Update the last check timestamp
    date +%s > "$UPDATE_CHECK_FILE"

    # Compare versions
    if [ -n "$CURRENT_APPIMAGE_VERSION" ] && [ "$LATEST_VERSION" = "$CURRENT_APPIMAGE_VERSION" ]; then
        log_info "You have the latest version (v$CURRENT_APPIMAGE_VERSION)."
        return 0
    fi

    # Version comparison function
    version_gt() {
        test "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" != "$1"
    }

    if [ -z "$CURRENT_APPIMAGE_VERSION" ] || version_gt "$LATEST_VERSION" "$CURRENT_APPIMAGE_VERSION"; then
        log_info "New version available: v$LATEST_VERSION (current: v${CURRENT_APPIMAGE_VERSION:-none})"
        log_info "Downloading update..."

        local NEW_APPIMAGE_PATH="$APPIMAGE_DIR/Claude_Desktop-${LATEST_VERSION}-aarch64-persistent.AppImage"
        local TEMP_APPIMAGE="/tmp/Claude_Desktop-${LATEST_VERSION}-aarch64.AppImage"

        if curl -L -f -o "$TEMP_APPIMAGE" "$DOWNLOAD_URL" 2>/dev/null; then
            log_info "Download complete. Installing..."
            mkdir -p "$APPIMAGE_DIR"
            mv "$TEMP_APPIMAGE" "$NEW_APPIMAGE_PATH"
            chmod +x "$NEW_APPIMAGE_PATH"
            log_info "✓ Updated to v$LATEST_VERSION"

            # Update APPIMAGE_PATH to the new file
            APPIMAGE_PATH="$NEW_APPIMAGE_PATH"
        else
            # Silently continue with existing version
            rm -f "$TEMP_APPIMAGE" 2>/dev/null
        fi
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
