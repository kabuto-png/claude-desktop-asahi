#!/bin/bash

# Claude Desktop Kill Script
# Safely terminates Claude Desktop and cleans up all related processes

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

# Function to kill Claude Desktop
kill_claude_desktop() {
    log_info "=== Claude Desktop Terminator ==="
    
    PID_FILE="$HOME/.cache/claude-desktop.pid"
    FOUND_PROCESSES=0
    
    # 1. Kill by PID file first (most accurate)
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            log_info "Killing Claude Desktop by PID file: $PID"
            kill -TERM "$PID" 2>/dev/null || kill -KILL "$PID" 2>/dev/null || true
            FOUND_PROCESSES=1
        fi
        rm -f "$PID_FILE"
    fi
    
    # 2. Kill by AppImage pattern
    for pid in $(pgrep -f "Claude_Desktop.*AppImage"); do
        if [ -n "$pid" ]; then
            log_info "Killing Claude AppImage process: $pid"
            kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
            FOUND_PROCESSES=1
        fi
    done
    
    # 3. Kill by electron processes with Claude data directory
    for pid in $(pgrep -f "user-data-dir.*Claude"); do
        if [ -n "$pid" ]; then
            log_info "Killing Claude electron process: $pid"
            kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
            FOUND_PROCESSES=1
        fi
    done
    
    # 4. Kill by mount point pattern
    for pid in $(pgrep -f "/tmp/.mount_[Cc]laude"); do
        if [ -n "$pid" ]; then
            log_info "Killing Claude mount process: $pid"
            kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
            FOUND_PROCESSES=1
        fi
    done
    
    if [ $FOUND_PROCESSES -eq 0 ]; then
        log_warn "No Claude Desktop processes found running."
        return 0
    fi
    
    # Wait for graceful termination
    log_info "Waiting for processes to terminate gracefully..."
    sleep 3
    
    # Force kill any remaining processes
    for pid in $(pgrep -f "Claude_Desktop\|/tmp/\.mount_[Cc]laude\|user-data-dir.*Claude"); do
        if [ -n "$pid" ]; then
            log_warn "Force killing stubborn process: $pid"
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done
    
    # Clean up mounts
    for mount in $(mount | grep -o '/tmp/\.mount_[Cc]laude[^[:space:]]*' | sort -u); do
        if [ -d "$mount" ]; then
            log_info "Cleaning up mount: $mount"
            fusermount -u "$mount" 2>/dev/null || umount "$mount" 2>/dev/null || true
        fi
    done
    
    # Clean up temporary files
    rm -rf /tmp/.mount_[Cc]laude* 2>/dev/null || true
    rm -f /tmp/claude-desktop.lock 2>/dev/null || true
    
    log_info "Claude Desktop termination completed."
}

# Main execution
kill_claude_desktop
