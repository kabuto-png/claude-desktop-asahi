#!/bin/bash
# Investigate all possible version sources in Claude Desktop installer

echo "=== Investigating Claude Desktop Version Sources ==="
echo ""

# Check if we have a build directory
if [ ! -d build ]; then
    echo "No build directory found. Run ./build-appimage.sh first."
    exit 1
fi

cd build

echo "1. Version from .nupkg filename:"
NUPKG=$(find . -name "AnthropicClaude-*.nupkg" -print -quit 2>/dev/null)
if [ -n "$NUPKG" ]; then
    echo "   File: $(basename "$NUPKG")"
    VERSION_NUPKG=$(basename "$NUPKG" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+(?=-full)')
    echo "   Version: $VERSION_NUPKG"
fi

echo ""
echo "2. Checking for package.json or version files..."
if [ -d "lib/net45" ]; then
    # Check for version in various locations
    find lib/net45 -name "package.json" -o -name "*.json" | head -5 | while read f; do
        if grep -q "version" "$f" 2>/dev/null; then
            echo "   Found in: $f"
            grep -E '"version"|"productVersion"' "$f" | head -3
        fi
    done
fi

echo ""
echo "3. Checking app.asar metadata..."
if [ -f "lib/net45/resources/app.asar" ] && command -v asar &>/dev/null; then
    echo "   Extracting app.asar metadata..."
    asar list lib/net45/resources/app.asar | grep -E "package\.json|version" | head -5
    
    # Try to extract package.json
    if asar extract lib/net45/resources/app.asar /tmp/claude-app 2>/dev/null; then
        if [ -f /tmp/claude-app/package.json ]; then
            echo "   package.json content:"
            cat /tmp/claude-app/package.json | grep -E '"version"|"productVersion"|"name"' | head -5
        fi
        rm -rf /tmp/claude-app
    fi
fi

echo ""
echo "4. Checking Windows executable metadata..."
if [ -f "lib/net45/claude.exe" ] && command -v exiftool &>/dev/null; then
    echo "   Executable metadata:"
    exiftool lib/net45/claude.exe | grep -i version | head -5
elif [ -f "lib/net45/claude.exe" ] && command -v strings &>/dev/null; then
    echo "   Searching exe strings for version info..."
    strings lib/net45/claude.exe | grep -E "^[0-9]+\.[0-9]+\.[0-9]+" | head -5
fi

echo ""
echo "5. Checking nuspec file (if exists)..."
NUSPEC=$(find . -name "*.nuspec" -print -quit 2>/dev/null)
if [ -n "$NUSPEC" ]; then
    echo "   Found: $(basename "$NUSPEC")"
    grep -E "<version>|<id>" "$NUSPEC"
fi

cd ..
