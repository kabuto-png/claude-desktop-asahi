#!/bin/bash
# Quick script to check the actual version inside an AppImage

if [ -z "$1" ]; then
    echo "Usage: $0 <AppImage-file>"
    exit 1
fi

APPIMAGE="$1"

if [ ! -f "$APPIMAGE" ]; then
    echo "File not found: $APPIMAGE"
    exit 1
fi

echo "=== Checking AppImage Version ==="
echo "File: $APPIMAGE"
echo ""

# Extract and check desktop file
"$APPIMAGE" --appimage-extract usr/share/applications/*.desktop 2>/dev/null || \
"$APPIMAGE" --appimage-extract *.desktop 2>/dev/null

if [ -f squashfs-root/*.desktop ] || [ -f squashfs-root/usr/share/applications/*.desktop ]; then
    DESKTOP_FILE=$(find squashfs-root -name "*.desktop" -print -quit)
    echo "Version from desktop file:"
    grep -E "(X-AppImage-Version|Version)=" "$DESKTOP_FILE" || echo "  (not found)"
    echo ""
fi

# Check the nupkg if available
if [ -d build ]; then
    NUPKG=$(find build -name "AnthropicClaude-*.nupkg" -print -quit 2>/dev/null)
    if [ -n "$NUPKG" ]; then
        VERSION=$(basename "$NUPKG" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+(?=-full)')
        echo "Version from build artifacts: $VERSION"
    fi
fi

# Cleanup
rm -rf squashfs-root

