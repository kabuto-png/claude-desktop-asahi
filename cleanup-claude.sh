#!/bin/bash
# Quick cleanup script for Claude Desktop mount issues

echo "=== Claude Desktop Cleanup ==="

# Kill all Claude processes
echo "Stopping Claude processes..."
pkill -f claude-desktop 2>/dev/null || true
pkill -f "Claude_Desktop.*AppImage" 2>/dev/null || true
pkill -f "/tmp/.mount_claude" 2>/dev/null || true

# Wait for processes to exit
sleep 3

# Show current mounts
echo "Current Claude mounts:"
mount | grep claude || echo "No Claude mounts found"

# Clean up AppImage mounts
echo "Cleaning up AppImage mounts..."
for mount in $(mount | grep -o '/tmp/\.mount_claude[^[:space:]]*'); do
    echo "Unmounting: $mount"
    fusermount -u "$mount" 2>/dev/null || umount "$mount" 2>/dev/null || true
done

# Remove temporary files
echo "Removing temporary files..."
rm -rf /tmp/.mount_claude* 2>/dev/null || true
rm -f /tmp/claude-desktop.lock 2>/dev/null || true

echo "✅ Cleanup complete!"

# Show remaining processes
echo "Remaining Claude processes:"
ps aux | grep -E "(claude|electron)" | grep -v grep || echo "No Claude processes running"
