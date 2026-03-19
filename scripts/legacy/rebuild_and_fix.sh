#!/bin/bash
# Rebuild and fix Claude AppImage

set -e

echo "=== Rebuilding Claude AppImage with Data Persistence ==="

# Check if we have the build files
if [ ! -f "fedora_asahi_build_script.sh" ]; then
    echo "❌ fedora_asahi_build_script.sh not found"
    echo "Make sure you're in the correct directory with the build scripts"
    exit 1
fi

# Clean up any previous builds
echo "Cleaning up previous builds..."
rm -rf build/
rm -f Claude_Desktop-*.AppImage
rm -f runtime-aarch64
rm -f filesystem*.squashfs

# Run the main build script
echo "=== Running Main Build Script ==="
if ./scripts/builders/fedora_asahi_build_script.sh; then
    echo "✅ Main build script completed successfully"
    
    # Check if AppImage was created
    APPIMAGE=$(find . -name "Claude_Desktop-*.AppImage" -type f | head -1)
    if [ -n "$APPIMAGE" ]; then
        echo "✅ Found AppImage: $APPIMAGE"
        
        # Test the AppImage
        echo "Testing AppImage..."
        if chmod +x "$APPIMAGE" && "./$APPIMAGE" --version 2>/dev/null; then
            echo "✅ AppImage is working"
        else
            echo "⚠️  AppImage may need GUI to test"
        fi
        
        # Create a persistent version
        echo "=== Creating Persistent Version ==="
        
        # Extract for modification
        "./$APPIMAGE" --appimage-extract
        
        # Modify AppRun for persistence
        cat > squashfs-root/AppRun << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"

# Set up data persistence
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Create Claude directories
mkdir -p "$XDG_CONFIG_HOME/Claude"
mkdir -p "$XDG_DATA_HOME/Claude"
mkdir -p "$XDG_CACHE_HOME/Claude"

# Set up environment
export PATH="$HERE/usr/bin:$HERE/usr/lib/claude-desktop/node_modules/electron/dist:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/lib:$LD_LIBRARY_PATH"

# Find Electron
if [ -f "$HERE/usr/lib/claude-desktop/node_modules/electron/dist/electron" ]; then
    ELECTRON="$HERE/usr/lib/claude-desktop/node_modules/electron/dist/electron"
elif command -v electron &>/dev/null; then
    ELECTRON="electron"
else
    echo "Error: Electron not found"
    exit 1
fi

# Launch with persistence
exec "$ELECTRON" \
    --no-sandbox \
    --user-data-dir="$XDG_CONFIG_HOME/Claude" \
    "$HERE/usr/lib/claude-desktop/app.asar" \
    "$@"
EOF
        
        chmod +x squashfs-root/AppRun
        
        # Rebuild as persistent AppImage
        echo "Creating persistent AppImage..."
        
        # Download runtime if needed
        if [ ! -f runtime-aarch64 ]; then
            wget -O runtime-aarch64 https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-aarch64
        fi
        
        # Create persistent AppImage
        mksquashfs squashfs-root filesystem-persistent.squashfs -root-owned -noappend -comp xz
        cat runtime-aarch64 filesystem-persistent.squashfs > Claude_Desktop-0.9.3-aarch64-persistent.AppImage
        chmod +x Claude_Desktop-0.9.3-aarch64-persistent.AppImage
        
        # Clean up
        rm -rf squashfs-root filesystem-persistent.squashfs
        
        echo "✅ Created persistent AppImage: Claude_Desktop-0.9.3-aarch64-persistent.AppImage"
        echo ""
        echo "Data will persist in:"
        echo "  ~/.config/Claude/"
        echo "  ~/.local/share/Claude/"
        echo "  ~/.cache/Claude/"
        
        exit 0
    else
        echo "❌ AppImage not found after main build"
        echo "Trying manual builder..."
    fi
fi

# If main script failed, try manual builder
echo "=== Running Manual Builder ==="
if [ -d "build" ] && ./scripts/builders/manual_appimage_builder.sh; then
    echo "✅ Manual builder completed successfully"
    
    # Check if AppImage was created
    APPIMAGE=$(find . -name "Claude_Desktop-*.AppImage" -type f | head -1)
    if [ -n "$APPIMAGE" ]; then
        echo "✅ Found AppImage: $APPIMAGE"
        echo "Now run this script again to add persistence, or use the AppImage as-is"
    else
        echo "❌ No AppImage found after manual builder"
    fi
else
    echo "❌ Both build methods failed"
    echo "Check the build requirements:"
    echo "  - Run: sudo dnf install p7zip wget icoutils ImageMagick nodejs npm squashfs-tools"
    echo "  - Ensure you have internet connection"
    echo "  - Check if FUSE is working: ls -la /dev/fuse"
fi