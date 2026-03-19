#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Script to help find the latest Claude Desktop download URLs

echo "=== Claude Desktop Version Finder ==="
echo ""
echo "Checking common sources for latest version info..."
echo ""

# Method 1: Check the debian packaging project (often has version info)
echo "1. Checking github.com/aaddrick/claude-desktop-debian for version info..."
if command -v curl &>/dev/null; then
    DEBIAN_VERSION=$(curl -sL "https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || echo "Failed to fetch")
    echo "   Latest from debian project: $DEBIAN_VERSION"
fi

echo ""
echo "2. Recommended: Visit these URLs to find the latest version:"
echo "   - https://claude.com/download (official)"
echo "   - https://github.com/aaddrick/claude-desktop-debian/releases"
echo "   - https://community.chocolatey.org/packages/claude (Windows version tracker)"

echo ""
echo "3. Known download URLs (may need updating):"
echo "   ARM64: https://storage.googleapis.com/.../nest-win-arm64/Claude-Setup-arm64.exe"
echo "   x64:   https://storage.googleapis.com/.../nest-win-x64/Claude-Setup-x64.exe"

