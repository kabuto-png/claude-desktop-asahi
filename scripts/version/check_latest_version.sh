#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Check if there's a newer Claude Desktop version available

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Claude Desktop Version Checker ==="
echo ""

# Your current version
CURRENT_VERSION=$(ls "$PROJECT_DIR"/Claude_Desktop-*.AppImage 2>/dev/null | grep -oP 'Claude_Desktop-\K[0-9]+(\.[0-9]+)+' | head -1)
if [ -n "$CURRENT_VERSION" ]; then
    echo "Your version: $CURRENT_VERSION"
else
    echo "Your version: Not built yet"
fi

echo ""
echo "Checking latest available version..."

# Check debian packaging project (reliable source for version tracking)
if command -v curl &>/dev/null; then
    LATEST=$(curl -sL "https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest" 2>/dev/null | grep '"tag_name"' | grep -oP 'claude\K[0-9]+\.[0-9]+\.[0-9]+' || echo "")

    if [ -n "$LATEST" ]; then
        echo "Latest version: $LATEST"
        echo ""

        if [ "$CURRENT_VERSION" = "$LATEST" ]; then
            echo "✅ You have the latest version!"
        elif [ -z "$CURRENT_VERSION" ]; then
            echo "ℹ️  Run $PROJECT_DIR/build-appimage.sh to build version $LATEST"
        else
            echo "⚠️  Newer version available: $LATEST (you have $CURRENT_VERSION)"
            echo ""
            echo "To update:"
            echo "  1. Check https://github.com/aaddrick/claude-desktop-debian/releases"
            echo "  2. Find the ARM64 download URL for version $LATEST"
            echo "  3. Run: $PROJECT_DIR/build-appimage.sh --claude-download-url <new-url>"
        fi
    else
        echo "❌ Could not check latest version (API rate limit or network issue)"
        echo ""
        echo "Manual check: https://github.com/aaddrick/claude-desktop-debian/releases"
    fi
else
    echo "❌ curl not installed"
    echo "Install: sudo dnf install curl"
fi

echo ""
echo "Official sources:"
echo "  - https://claude.com/download"
echo "  - https://github.com/aaddrick/claude-desktop-debian/releases"
