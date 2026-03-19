#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

# Claude Desktop Status Checker

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

log_status() {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

# Function to check Claude Desktop status
check_claude_status() {
    log_info "=== Claude Desktop Status Check ==="
    
    PID_FILE="$HOME/.cache/claude-desktop.pid"
    RUNNING_PROCESSES=()
    
    # Check PID file
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            log_status "PID file exists and process is running: $PID"
            RUNNING_PROCESSES+=("PID_FILE:$PID")
        else
            log_warn "PID file exists but process is not running (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        log_status "No PID file found"
    fi
    
    # Check AppImage processes
    for pid in $(pgrep -f "Claude_Desktop.*AppImage"); do
        if [ -n "$pid" ]; then
            CMD=$(ps -p "$pid" -o cmd --no-headers 2>/dev/null)
            log_status "Claude AppImage process running: PID $pid"
            echo "  Command: $CMD"
            RUNNING_PROCESSES+=("APPIMAGE:$pid")
        fi
    done
    
    # Check electron processes
    for pid in $(pgrep -f "user-data-dir.*Claude"); do
        if [ -n "$pid" ]; then
            CMD=$(ps -p "$pid" -o cmd --no-headers 2>/dev/null)
            log_status "Claude electron process running: PID $pid"
            echo "  Command: ${CMD:0:80}..."
            RUNNING_PROCESSES+=("ELECTRON:$pid")
        fi
    done
    
    # Check mount points
    MOUNTS=$(mount | grep '/tmp/\.mount_[Cc]laude' | wc -l)
    if [ $MOUNTS -gt 0 ]; then
        log_status "Active Claude mounts: $MOUNTS"
        mount | grep '/tmp/\.mount_[Cc]laude' | while read line; do
            echo "  $line"
        done
    fi
    
    # Summary
    echo ""
    if [ ${#RUNNING_PROCESSES[@]} -eq 0 ]; then
        log_error "Claude Desktop is NOT running"
        exit 1
    else
        log_info "Claude Desktop is RUNNING with ${#RUNNING_PROCESSES[@]} processes"
        echo ""
        log_info "To kill Claude Desktop, run: claude-kill"
        exit 0
    fi
}

# Main execution
check_claude_status
