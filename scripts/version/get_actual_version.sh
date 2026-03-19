#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Get the actual Claude Desktop version from app.asar package.json
# This is the most reliable source of truth for the version

set -e

WORK_DIR="build"

echo "=== Getting Actual Claude Desktop Version ==="

# Method 1: Extract from app.asar package.json (most reliable)
if [ -f "$WORK_DIR/lib/net45/resources/app.asar" ]; then
    echo "Found app.asar, extracting version from package.json..."

    # Create temp directory
    TEMP_DIR=$(mktemp -d)

    # Extract app.asar
    if command -v asar &>/dev/null; then
        asar extract "$WORK_DIR/lib/net45/resources/app.asar" "$TEMP_DIR" 2>/dev/null || {
            echo "Failed to extract app.asar"
            rm -rf "$TEMP_DIR"
            exit 1
        }

        # Read version from package.json
        if [ -f "$TEMP_DIR/package.json" ]; then
            VERSION=$(grep -oP '"version"\s*:\s*"\K[^"]+' "$TEMP_DIR/package.json" || echo "")

            if [ -n "$VERSION" ]; then
                echo "✅ Version from app.asar package.json: $VERSION"
                echo "$VERSION"
                rm -rf "$TEMP_DIR"
                exit 0
            fi
        fi

        rm -rf "$TEMP_DIR"
    else
        echo "⚠️  asar tool not found, cannot extract app.asar"
    fi
fi

# Method 2: Fallback to .nupkg filename
NUPKG=$(find "$WORK_DIR" -name "AnthropicClaude-*.nupkg" -print -quit 2>/dev/null || true)
if [ -n "$NUPKG" ]; then
    VERSION=$(basename "$NUPKG" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+(?=-full)' || echo "")
    if [ -n "$VERSION" ]; then
        echo "⚠️  Version from .nupkg filename: $VERSION (fallback method)"
        echo "$VERSION"
        exit 0
    fi
fi

# Method 3: Check desktop file
if [ -f "$WORK_DIR/ClaudeDesktop.AppDir/claude-desktop.desktop" ]; then
    VERSION=$(grep "X-AppImage-Version=" "$WORK_DIR/ClaudeDesktop.AppDir/claude-desktop.desktop" 2>/dev/null | cut -d'=' -f2 || echo "")
    if [ -n "$VERSION" ]; then
        echo "⚠️  Version from desktop file: $VERSION (fallback method)"
        echo "$VERSION"
        exit 0
    fi
fi

echo "❌ Could not determine version"
exit 1
