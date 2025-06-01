#!/bin/bash
set -e

echo "=== Adding Data Persistence to Claude AppImage ==="

# Check if the AppImage exists
APPIMAGE="Claude_Desktop-0.9.3-aarch64.AppImage"
if [ ! -f "$APPIMAGE" ]; then
    echo "❌ AppImage not found: $APPIMAGE"
    exit 1
fi

echo "Found AppImage: $APPIMAGE"

# Clean up any previous extractions
rm -rf squashfs-root

# Extract the AppImage
echo "Extracting AppImage..."
./"$APPIMAGE" --appimage-extract

# Verify extraction
if [ ! -d "squashfs-root" ]; then
    echo "❌ Extraction failed"
    exit 1
fi

echo "✓ AppImage extracted successfully"

# Backup original AppRun
cp squashfs-root/AppRun squashfs-root/AppRun.backup

# Create new AppRun with data persistence
echo "Creating persistent AppRun..."
cat > squashfs-root/AppRun << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"

# Set up data persistence directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Create Claude directories
mkdir -p "$XDG_CONFIG_HOME/Claude"
mkdir -p "$XDG_DATA_HOME/Claude"
mkdir -p "$XDG_CACHE_HOME/Claude"

# Set proper permissions
chmod 755 "$XDG_CONFIG_HOME/Claude" 2>/dev/null || true
chmod 755 "$XDG_DATA_HOME/Claude" 2>/dev/null || true
chmod 755 "$XDG_CACHE_HOME/Claude" 2>/dev/null || true

# For Fedora Asahi ARM64
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

# Launch with data persistence
exec "$ELECTRON" \
    --no-sandbox \
    --user-data-dir="$XDG_CONFIG_HOME/Claude" \
    "$HERE/usr/lib/claude-desktop/app.asar" \
    "$@"
EOF

chmod +x squashfs-root/AppRun

echo "✓ Created persistent AppRun"

# Rebuild the AppImage
echo "Rebuilding AppImage with persistence..."

# Download runtime if needed
if [ ! -f runtime-aarch64 ]; then
    echo "Downloading ARM64 runtime..."
    wget -O runtime-aarch64 https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-aarch64
fi

# Create the persistent AppImage
echo "Creating SquashFS filesystem..."
mksquashfs squashfs-root filesystem-persistent.squashfs -root-owned -noappend -comp xz

echo "Assembling persistent AppImage..."
cat runtime-aarch64 filesystem-persistent.squashfs > Claude_Desktop-0.9.3-aarch64-persistent.AppImage
chmod +x Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Clean up
rm -rf squashfs-root filesystem-persistent.squashfs

echo ""
echo "✅ SUCCESS! Created persistent Claude AppImage!"
echo ""
echo "Files created:"
echo "  Original: $APPIMAGE"
echo "  Persistent: Claude_Desktop-0.9.3-aarch64-persistent.AppImage"
echo ""
echo "Your data will now persist in:"
echo "  Configuration: ~/.config/Claude/"
echo "  App Data:      ~/.local/share/Claude/"
echo "  Cache:         ~/.cache/Claude/"
echo ""
echo "Test the persistent version:"
echo "./Claude_Desktop-0.9.3-aarch64-persistent.AppImage"