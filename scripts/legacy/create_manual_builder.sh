#!/bin/bash
# Create the manual AppImage builder script

echo "Creating manual_appimage_builder.sh..."

cat > manual_appimage_builder.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Manual AppImage Builder for ARM64 ==="

WORK_DIR="$(pwd)/build"
APP_DIR="$WORK_DIR/ClaudeDesktop.AppDir"
VERSION="0.9.3"

if [ ! -d "$APP_DIR" ]; then
    echo "❌ AppDir not found. Run the main build script first."
    exit 1
fi

echo "Creating AppImage manually..."

# Method 1: Try to fix the appimagetool architecture detection
echo "=== Method 1: Fixing Architecture Detection ==="

# Create a proper ELF binary for architecture detection
# Copy the electron binary to help appimagetool detect architecture
if [ -f "$APP_DIR/usr/lib/claude-desktop/node_modules/electron/dist/electron" ]; then
    echo "Copying electron binary for architecture detection..."
    cp "$APP_DIR/usr/lib/claude-desktop/node_modules/electron/dist/electron" "$APP_DIR/usr/bin/"
    
    # Try building again
    cd "$WORK_DIR"
    if env ARCH=aarch64 /usr/local/bin/appimagetool "$APP_DIR" "Claude_Desktop-${VERSION}-aarch64.AppImage"; then
        echo "✅ Method 1 successful!"
        chmod +x "Claude_Desktop-${VERSION}-aarch64.AppImage"
        mv "Claude_Desktop-${VERSION}-aarch64.AppImage" "../"
        cd ..
        rm -rf build
        exit 0
    fi
fi

echo "Method 1 failed, trying Method 2..."

# Method 2: Manual AppImage creation using runtime
echo "=== Method 2: Manual Runtime Assembly ==="

cd "$WORK_DIR"

# Download ARM64 runtime
echo "Downloading ARM64 AppImage runtime..."
wget -O runtime-aarch64 https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-aarch64
chmod +x runtime-aarch64

# Create SquashFS filesystem
echo "Creating SquashFS filesystem..."
if command -v mksquashfs &>/dev/null; then
    mksquashfs "$APP_DIR" filesystem.squashfs -root-owned -noappend -comp xz
    
    # Combine runtime and filesystem
    echo "Assembling AppImage..."
    cat runtime-aarch64 filesystem.squashfs > "Claude_Desktop-${VERSION}-aarch64.AppImage"
    chmod +x "Claude_Desktop-${VERSION}-aarch64.AppImage"
    
    # Move to parent directory
    mv "Claude_Desktop-${VERSION}-aarch64.AppImage" "../"
    echo "✅ Method 2 successful!"
    cd ..
    rm -rf build
    exit 0
else
    echo "mksquashfs not found, installing..."
    sudo dnf install -y squashfs-tools
    
    # Try again
    mksquashfs "$APP_DIR" filesystem.squashfs -root-owned -noappend -comp xz
    cat runtime-aarch64 filesystem.squashfs > "Claude_Desktop-${VERSION}-aarch64.AppImage"
    chmod +x "Claude_Desktop-${VERSION}-aarch64.AppImage"
    mv "Claude_Desktop-${VERSION}-aarch64.AppImage" "../"
    echo "✅ Method 2 successful!"
    cd ..
    rm -rf build
    exit 0
fi

echo "Method 2 failed, trying Method 3..."

# Method 3: Use alternative AppImage creation tool
echo "=== Method 3: Alternative Tools ==="

# Try using appimage-builder if available
if command -v appimage-builder &>/dev/null; then
    echo "Using appimage-builder..."
    
    # Create appimage-builder config
    cat > AppImageBuilder.yml << EOFBUILDER
version: 1

AppDir:
  path: $APP_DIR
  app_info:
    id: com.anthropic.claude
    name: Claude
    icon: claude-desktop
    version: $VERSION
    exec: usr/bin/AppRun
    exec_args: \$@

  runtime:
    arch: aarch64
    
AppImage:
  arch: aarch64
  comp: xz
  update-information: false
EOFBUILDER
    
    if appimage-builder --recipe AppImageBuilder.yml; then
        echo "✅ Method 3 successful!"
        mv *.AppImage "../Claude_Desktop-${VERSION}-aarch64.AppImage"
        cd ..
        rm -rf build
        exit 0
    fi
fi

echo "=== Method 4: Force Architecture Flag ==="

# Try forcing the architecture detection by modifying the appimagetool
echo "Attempting to force architecture detection..."

# Create a wrapper that forces the architecture
cat > force-arch-appimagetool << 'EOFFORCE'
#!/bin/bash
export ARCH=aarch64
exec /usr/local/bin/appimagetool "$@"
EOFFORCE
chmod +x force-arch-appimagetool

if ./force-arch-appimagetool "$APP_DIR" "Claude_Desktop-${VERSION}-aarch64.AppImage"; then
    echo "✅ Method 4 successful!"
    chmod +x "Claude_Desktop-${VERSION}-aarch64.AppImage"
    mv "Claude_Desktop-${VERSION}-aarch64.AppImage" "../"
    cd ..
    rm -rf build
    exit 0
fi

echo "❌ All methods failed. Manual intervention required."
echo "The AppDir is ready at: $APP_DIR"
echo "You can try:"
echo "1. Install a different version of appimagetool"
echo "2. Use a different AppImage creation tool"
echo "3. Create the AppImage on a different system"

exit 1
EOF

chmod +x manual_appimage_builder.sh
echo "✅ Created manual_appimage_builder.sh"