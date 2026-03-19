#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Fixed Claude Desktop Launcher for Fedora Asahi - Version 2
# Addresses multiple mount issues and ARM64 graphics problems



# Configuration
APPIMAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="/tmp/claude-desktop.lock"
PID_FILE="$HOME/.cache/claude-desktop.pid"
UPDATE_CHECK_FILE="$HOME/.cache/claude-desktop-update-check"
UPDATE_CHECK_INTERVAL=$((30 * 24 * 60 * 60))  # 30 days in seconds
DISABLE_UPDATE_CHECK=true  # Set to true to disable automatic update checks (useful for local builds)
VERSION_CHECKER_SCRIPT="$APPIMAGE_DIR/scripts/version/check-official-version.sh"

# Function to find the latest AppImage in the directory
find_latest_appimage() {
    # Find all Claude Desktop AppImages (any variation)
    # Use /usr/bin/find to avoid fd alias
    local latest_any=$(/usr/bin/find "$APPIMAGE_DIR" -maxdepth 1 -name "Claude_Desktop-*-aarch64*.AppImage" -type f 2>/dev/null | sort -V | tail -n 1)

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

# Fix auth config directory and file permissions
fix_auth_permissions() {
    local AUTH_CONFIG_DIR="$XDG_CONFIG_HOME/Claude"
    local AUTH_CONFIG_FILE="$AUTH_CONFIG_DIR/config.json"

    [ -d "$AUTH_CONFIG_DIR" ] && chmod 700 "$AUTH_CONFIG_DIR"
    [ -f "$AUTH_CONFIG_FILE" ] && chmod 600 "$AUTH_CONFIG_FILE"
}

# Clear stale OAuth token cache if config is older than 48h
clear_stale_token_cache() {
    local AUTH_CONFIG_FILE="$XDG_CONFIG_HOME/Claude/config.json"

    if [ -f "$AUTH_CONFIG_FILE" ] && command -v jq &>/dev/null; then
        # Validate JSON before attempting modification
        if ! jq empty "$AUTH_CONFIG_FILE" 2>/dev/null; then
            return 0
        fi

        local file_age=$(( $(date +%s) - $(stat -c %Y "$AUTH_CONFIG_FILE" 2>/dev/null || echo "0") ))
        if [ "$file_age" -gt 172800 ]; then  # 48 hours in seconds
            log_info "Clearing stale auth token cache (config is $(( file_age / 3600 ))h old)..."
            local backup="$AUTH_CONFIG_FILE.backup.$(date +%s)"
            cp "$AUTH_CONFIG_FILE" "$backup"
            if jq 'with_entries(select(.key | startswith("oauth") | not))' "$AUTH_CONFIG_FILE" > "$AUTH_CONFIG_FILE.tmp" 2>/dev/null && [ -s "$AUTH_CONFIG_FILE.tmp" ]; then
                mv "$AUTH_CONFIG_FILE.tmp" "$AUTH_CONFIG_FILE"
                chmod 600 "$AUTH_CONFIG_FILE"
                log_info "Token cache cleared (backup: $backup)"
            else
                rm -f "$AUTH_CONFIG_FILE.tmp"
            fi
        fi
    fi
}

# Detect display scale factor for HiDPI
detect_scale_factor() {
    local scale=1

    # Try to get scale from GDK_SCALE if set
    if [ -n "$GDK_SCALE" ]; then
        scale="$GDK_SCALE"
    # Try to detect from gsettings (GNOME)
    elif command -v gsettings &>/dev/null; then
        local gnome_scale=$(gsettings get org.gnome.desktop.interface scaling-factor 2>/dev/null | tr -d "'")
        if [ -n "$gnome_scale" ] && [ "$gnome_scale" -gt 0 ] 2>/dev/null; then
            scale="$gnome_scale"
        fi
        # Also check text-scaling-factor for fractional scaling
        local text_scale=$(gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null)
        if [ -n "$text_scale" ]; then
            # If text scaling > 1.5, assume HiDPI
            if awk "BEGIN {exit !($text_scale >= 1.5)}"; then
                scale=2
            fi
        fi
    fi

    # Asahi Linux on Apple Silicon typically needs 2x scaling
    if grep -q "Apple" /proc/cpuinfo 2>/dev/null; then
        scale=2
    fi

    echo "$scale"
}

# Function to set up environment for Fedora Asahi ARM64
setup_environment() {
    log_info "Setting up environment for Fedora Asahi ARM64..."

    # Detect and set display scaling (only if not manually set)
    if [ -z "$SCALE_FACTOR" ]; then
        SCALE_FACTOR=$(detect_scale_factor)
        log_info "Auto-detected scale factor: ${SCALE_FACTOR}x"
    else
        log_info "Using manual scale factor: ${SCALE_FACTOR}x"
    fi

    # HiDPI scaling for GTK/Qt applications
    export GDK_SCALE="${GDK_SCALE:-$SCALE_FACTOR}"
    export GDK_DPI_SCALE="${GDK_DPI_SCALE:-1}"
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    export QT_SCALE_FACTOR="${QT_SCALE_FACTOR:-$SCALE_FACTOR}"

    # Graphics and display fixes for ARM64/Asahi
    export ELECTRON_OZONE_PLATFORM_HINT=auto
    export ELECTRON_DISABLE_SECURITY_WARNINGS=true
    export ELECTRON_FORCE_DEVICE_SCALE_FACTOR="$SCALE_FACTOR"
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

# Version comparison: returns 0 if $1 > $2
version_gt() {
    test "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" != "$1"
}

# Get current installed version from AppImage filename
get_current_version() {
    if [ -n "$APPIMAGE_PATH" ] && [ -f "$APPIMAGE_PATH" ]; then
        basename "$APPIMAGE_PATH" | sed -n 's/Claude_Desktop-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-aarch64.*\.AppImage/\1/p'
    fi
}

# Get latest version using official Anthropic endpoint (with cache + GitHub fallback)
get_latest_version() {
    # Source the version checker if available
    if [ -f "$VERSION_CHECKER_SCRIPT" ]; then
        source "$VERSION_CHECKER_SCRIPT"
        get_latest_version
        return $?
    fi

    # Inline fallback if version checker script is missing
    if ! command -v curl &>/dev/null; then
        return 1
    fi

    # Try official Anthropic RELEASES endpoint (no Cloudflare)
    local version
    version=$(curl -sf --connect-timeout 5 --max-time 10 \
        "https://downloads.claude.ai/releases/win32/arm64/RELEASES" 2>/dev/null \
        | tail -1 | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+')

    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi

    # Fallback: GitHub API
    if command -v jq &>/dev/null; then
        version=$(curl -sf --connect-timeout 5 --max-time 10 \
            "https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest" 2>/dev/null \
            | jq -r '.assets[] | select(.name | contains("arm64.AppImage") and (contains(".zsync") | not)) | .name' 2>/dev/null \
            | head -1 | grep -oP 'claude-desktop-\K[0-9]+\.[0-9]+\.[0-9]+')

        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    return 1
}

# Get download URL from GitHub for arm64 AppImage
get_download_url() {
    if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
        return 1
    fi

    curl -sf --connect-timeout 5 --max-time 10 \
        "https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest" 2>/dev/null \
        | jq -r '.assets[] | select(.name | contains("arm64.AppImage") and (contains(".zsync") | not)) | .browser_download_url' 2>/dev/null \
        | head -1
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

    local CURRENT_APPIMAGE_VERSION
    CURRENT_APPIMAGE_VERSION=$(get_current_version)

    local LATEST_VERSION
    LATEST_VERSION=$(get_latest_version)

    if [ -z "$LATEST_VERSION" ]; then
        log_warn "Could not determine latest version. Skipping update check."
        return 0
    fi

    # Update the last check timestamp
    date +%s > "$UPDATE_CHECK_FILE"

    # Compare versions
    if [ -n "$CURRENT_APPIMAGE_VERSION" ] && [ "$LATEST_VERSION" = "$CURRENT_APPIMAGE_VERSION" ]; then
        log_info "You have the latest version (v$CURRENT_APPIMAGE_VERSION)."
        return 0
    fi

    if [ -z "$CURRENT_APPIMAGE_VERSION" ] || version_gt "$LATEST_VERSION" "$CURRENT_APPIMAGE_VERSION"; then
        log_info "New version available: v$LATEST_VERSION (current: v${CURRENT_APPIMAGE_VERSION:-none})"

        local DOWNLOAD_URL
        DOWNLOAD_URL=$(get_download_url)

        if [ -z "$DOWNLOAD_URL" ]; then
            log_warn "Could not get download URL. Skipping update."
            return 0
        fi

        log_info "Downloading update from GitHub..."
        local NEW_APPIMAGE_PATH="$APPIMAGE_DIR/Claude_Desktop-${LATEST_VERSION}-aarch64-persistent.AppImage"
        local TEMP_APPIMAGE="/tmp/Claude_Desktop-${LATEST_VERSION}-aarch64.AppImage.tmp"

        if curl -L -f --progress-bar -o "$TEMP_APPIMAGE" "$DOWNLOAD_URL" 2>/dev/null; then
            # Verify download: file must be > 1MB (sanity check for AppImage)
            local FILE_SIZE
            FILE_SIZE=$(stat -c%s "$TEMP_APPIMAGE" 2>/dev/null || echo "0")
            if [ "$FILE_SIZE" -lt 1048576 ]; then
                log_error "Downloaded file too small (${FILE_SIZE} bytes). Discarding."
                rm -f "$TEMP_APPIMAGE" 2>/dev/null
                return 0
            fi

            # Atomic move: temp -> final
            log_info "Download complete. Installing..."
            mkdir -p "$APPIMAGE_DIR"
            mv "$TEMP_APPIMAGE" "$NEW_APPIMAGE_PATH"
            chmod +x "$NEW_APPIMAGE_PATH"
            log_info "Updated to v$LATEST_VERSION"

            # Update APPIMAGE_PATH to the new file
            APPIMAGE_PATH="$NEW_APPIMAGE_PATH"
        else
            log_warn "Download failed. Continuing with current version."
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

    # Launch with proper flags for Asahi Linux ARM64 + HiDPI scaling
    "$APPIMAGE_PATH" \
        --no-sandbox \
        --disable-gpu-sandbox \
        --disable-software-rasterizer \
        --disable-dev-shm-usage \
        --disable-extensions \
        --disable-plugins \
        --single-instance \
        --force-device-scale-factor="$SCALE_FACTOR" \
        --high-dpi-support=1 \
        --enable-features=UseOzonePlatform,WaylandWindowDecorations \
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
    # Handle --diagnose flag
    if [ "${1:-}" = "--diagnose" ]; then
        local DIAG_SCRIPT="$APPIMAGE_DIR/scripts/tools/claude-auth-diagnostics.sh"
        if [ -f "$DIAG_SCRIPT" ]; then
            bash "$DIAG_SCRIPT"
        else
            log_error "Diagnostics script not found: $DIAG_SCRIPT"
        fi
        exit 0
    fi

    # Handle --scale flag for manual HiDPI scaling
    if [ "${1:-}" = "--scale" ] && [ -n "${2:-}" ]; then
        export SCALE_FACTOR="$2"
        log_info "Manual scale factor set: ${SCALE_FACTOR}x"
        shift 2
    fi

    # Handle --help flag
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        echo "Claude Desktop Launcher for Fedora Asahi ARM64"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --diagnose    Run authentication diagnostics"
        echo "  --scale N     Set display scale factor (1, 1.5, 2, etc.)"
        echo "  --help, -h    Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                  # Auto-detect scale, launch normally"
        echo "  $0 --scale 2        # Force 2x scaling for HiDPI"
        echo "  $0 --scale 1.5      # Force 1.5x scaling"
        echo "  $0 --diagnose       # Check auth status"
        exit 0
    fi

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

    # Fix auth permissions and clear stale tokens
    fix_auth_permissions
    clear_stale_token_cache

    # Launch Claude
    launch_claude "$@"
}

# Run main function
main "$@"
