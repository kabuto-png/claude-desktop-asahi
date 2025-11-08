#!/bin/bash
set -e

# Fedora Asahi specific build script for Claude Desktop AppImage

# Check we're on Fedora Asahi
if ! grep -q "Fedora Linux Asahi" /etc/os-release 2>/dev/null; then
    echo "⚠️  This script is optimized for Fedora Asahi Remix"
fi

ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "❌ This script is for ARM64/aarch64 systems only. Detected: $ARCH"
    exit 1
fi

echo "=== Fedora Asahi Claude Desktop AppImage Builder ==="
echo "Architecture: $ARCH"
echo "Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"

# Configuration
ELECTRON_BUNDLED=1  # Always bundle on Asahi for compatibility
CLAUDE_DOWNLOAD_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-arm64/Claude-Setup-arm64.exe"
APP_IMAGE_TOOL="/usr/local/bin/appimagetool"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --claude-download-url)
            CLAUDE_DOWNLOAD_URL="$2"
            shift 2
            ;;
        --no-bundle-electron)
            ELECTRON_BUNDLED=0
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--claude-download-url <url>] [--no-bundle-electron] [-h|--help]"
            echo "  --claude-download-url <url>  URL to download Claude installer"
            echo "  --no-bundle-electron         Don't bundle Electron (use system version)"
            echo "  -h, --help                   Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check and fix FUSE setup for Fedora Asahi
echo "=== Checking FUSE Setup ==="
if [ ! -c /dev/fuse ]; then
    echo "❌ FUSE device not found. Loading FUSE module..."
    sudo modprobe fuse
fi

# Check FUSE permissions
if [ ! -r /dev/fuse ] || [ ! -w /dev/fuse ]; then
    echo "🔧 Fixing FUSE permissions for Fedora Asahi..."
    
    # Create udev rule for persistent fix
    echo 'KERNEL=="fuse", MODE="0666"' | sudo tee /etc/udev/rules.d/99-fuse.rules >/dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    # Immediate fix
    sudo chmod 666 /dev/fuse
fi

if [ -r /dev/fuse ] && [ -w /dev/fuse ]; then
    echo "✓ FUSE is properly configured"
else
    echo "❌ FUSE permissions still not correct. Manual intervention needed."
    exit 1
fi

# Check dependencies
echo "=== Checking Dependencies ==="
MISSING_DEPS=""

for cmd in 7z wget wrestool icotool convert npm; do
    if ! command -v "$cmd" &>/dev/null; then
        case "$cmd" in
            "7z") MISSING_DEPS="$MISSING_DEPS p7zip" ;;
            "wget") MISSING_DEPS="$MISSING_DEPS wget" ;;
            "wrestool"|"icotool") MISSING_DEPS="$MISSING_DEPS icoutils" ;;
            "convert") MISSING_DEPS="$MISSING_DEPS ImageMagick" ;;
            "npm") MISSING_DEPS="$MISSING_DEPS nodejs npm" ;;
        esac
        echo "❌ $cmd not found"
    else
        echo "✓ $cmd found"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "Installing missing dependencies..."
    sudo dnf install -y $MISSING_DEPS
fi

# Check/install ARM64 appimagetool
echo "=== Setting up AppImageTool ==="
if [ ! -f "$APP_IMAGE_TOOL" ] || ! file "$APP_IMAGE_TOOL" | grep -q "aarch64"; then
    echo "Installing ARM64 AppImageTool..."
    
    # Download ARM64 version
    wget -O /tmp/appimagetool-aarch64.AppImage \
        https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-aarch64.AppImage
    
    chmod +x /tmp/appimagetool-aarch64.AppImage
    
    # Test it works
    if /tmp/appimagetool-aarch64.AppImage --version >/dev/null 2>&1; then
        sudo mv /tmp/appimagetool-aarch64.AppImage "$APP_IMAGE_TOOL"
        echo "✓ ARM64 AppImageTool installed"
    else
        echo "❌ ARM64 AppImageTool test failed. Trying alternative approach..."
        # Try with --appimage-extract-and-run
        if /tmp/appimagetool-aarch64.AppImage --appimage-extract-and-run --version >/dev/null 2>&1; then
            # Create wrapper script
            cat > /tmp/appimagetool-wrapper << 'EOFWRAP'
#!/bin/bash
exec /usr/local/bin/appimagetool-aarch64.AppImage --appimage-extract-and-run "$@"
EOFWRAP
            chmod +x /tmp/appimagetool-wrapper
            sudo mv /tmp/appimagetool-aarch64.AppImage /usr/local/bin/appimagetool-aarch64.AppImage
            sudo mv /tmp/appimagetool-wrapper "$APP_IMAGE_TOOL"
            echo "✓ ARM64 AppImageTool installed with extract mode"
        else
            echo "❌ Could not get ARM64 AppImageTool working"
            exit 1
        fi
    fi
else
    echo "✓ ARM64 AppImageTool already installed"
fi

# Install/setup Electron with ARM64 support
echo "=== Setting up Electron ==="
if [ "$ELECTRON_BUNDLED" -eq 1 ]; then
    echo "Installing Electron locally for ARM64..."
    
    # Create package.json if needed
    if [ ! -f "package.json" ]; then
        cat > package.json << EOFPKG
{
  "name": "claude-desktop-appimage",
  "version": "1.0.0",
  "private": true,
  "devDependencies": {}
}
EOFPKG
    fi
    
    # Install Electron for ARM64
    npm install --save-dev electron@latest
    
    if [ -f "node_modules/.bin/electron" ]; then
        echo "✓ Electron installed locally"
        export PATH="$(pwd)/node_modules/.bin:$PATH"
    else
        echo "❌ Failed to install Electron locally"
        exit 1
    fi
else
    echo "Checking system Electron..."
    if ! command -v electron &>/dev/null; then
        echo "Installing Electron globally..."
        sudo npm install -g electron@latest
    fi
    echo "✓ Electron available"
fi

# Install asar
if ! command -v asar &>/dev/null; then
    echo "Installing asar..."
    npm install -g asar
fi
export PATH="/home/longne/.npm-global/bin:$PATH"

CURRENT_DIR="$(pwd)"
WORK_DIR="$CURRENT_DIR/build"
APP_DIR="$WORK_DIR/ClaudeDesktop.AppDir"

# Clean and create directories
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
mkdir -p "$APP_DIR"/usr/bin
mkdir -p "$APP_DIR"/usr/lib/claude-desktop
mkdir -p "$APP_DIR"/usr/share/applications
mkdir -p "$APP_DIR"/usr/share/icons/hicolor

# Download Claude if needed
CLAUDE_EXE="$WORK_DIR/Claude-Setup-x64.exe"
if [ ! -f "$CLAUDE_EXE" ]; then
    echo "=== Downloading Claude Desktop ==="
    wget -O "$CLAUDE_EXE" "$CLAUDE_DOWNLOAD_URL"
fi

# Extract and process (same as original script)
echo "=== Extracting Resources ==="
cd "$WORK_DIR"
7z x -y "$CLAUDE_EXE"

# Find and extract nupkg
NUPKG_PATH=$(find . -name "AnthropicClaude-*.nupkg" | head -1)
if [ -z "$NUPKG_PATH" ]; then
    echo "❌ Could not find nupkg file"
    exit 1
fi

# Extract nupkg first
7z x -y "$NUPKG_PATH"

# Get actual version from app.asar package.json (most reliable)
echo "Detecting version from app.asar..."
VERSION=""
if [ -f "lib/net45/resources/app.asar" ]; then
    TEMP_EXTRACT=$(mktemp -d)
    if asar extract lib/net45/resources/app.asar "$TEMP_EXTRACT" 2>/dev/null; then
        if [ -f "$TEMP_EXTRACT/package.json" ]; then
            VERSION=$(grep -oP '"version"\s*:\s*"\K[^"]+' "$TEMP_EXTRACT/package.json" 2>/dev/null || echo "")
        fi
        rm -rf "$TEMP_EXTRACT"
    fi
fi

# Fallback to nupkg filename if app.asar extraction failed
if [ -z "$VERSION" ]; then
    echo "⚠️  Could not extract version from app.asar, using nupkg filename..."
    VERSION=$(basename "$NUPKG_PATH" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+(?=-full)')
fi

echo "✓ Detected version: $VERSION"

# Extract icons
echo "=== Processing Icons ==="
wrestool -x -t 14 "lib/net45/claude.exe" -o claude.ico
icotool -x claude.ico

# Icon mapping
declare -A icon_files=(
    ["16"]="claude_13_16x16x32.png"
    ["24"]="claude_11_24x24x32.png" 
    ["32"]="claude_10_32x32x32.png"
    ["48"]="claude_8_48x48x32.png"
    ["64"]="claude_7_64x64x32.png"
    ["256"]="claude_6_256x256x32.png"
)

# Install icons
for size in 16 24 32 48 64 256; do
    icon_dir="$APP_DIR/usr/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$icon_dir"
    if [ -f "${icon_files[$size]}" ]; then
        cp "${icon_files[$size]}" "$icon_dir/claude-desktop.png"
        if [ "$size" == "256" ]; then
            cp "${icon_files[$size]}" "$APP_DIR/.DirIcon"
            cp "${icon_files[$size]}" "$APP_DIR/claude-desktop.png"
        fi
    fi
done

# Process app.asar
echo "=== Processing Application ==="
mkdir -p electron-app
cp "lib/net45/resources/app.asar" electron-app/
cp -r "lib/net45/resources/app.asar.unpacked" electron-app/

cd electron-app
asar extract app.asar app.asar.contents

# Create stub native module
cat > app.asar.contents/node_modules/claude-native/index.js << 'EOFSTUB'
const KeyboardKey = {
  Backspace: 43, Tab: 280, Enter: 261, Shift: 272, Control: 61, Alt: 40,
  CapsLock: 56, Escape: 85, Space: 276, PageUp: 251, PageDown: 250,
  End: 83, Home: 154, LeftArrow: 175, UpArrow: 282, RightArrow: 262,
  DownArrow: 81, Delete: 79, Meta: 187
};

Object.freeze(KeyboardKey);

module.exports = {
  getWindowsVersion: () => "10.0.0",
  setWindowEffect: () => {}, removeWindowEffect: () => {}, getIsMaximized: () => false,
  flashFrame: () => {}, clearFlashFrame: () => {}, showNotification: () => {},
  setProgressBar: () => {}, clearProgressBar: () => {}, setOverlayIcon: () => {},
  clearOverlayIcon: () => {}, KeyboardKey
};
EOFSTUB

# Copy resources
mkdir -p app.asar.contents/resources/i18n
cp ../lib/net45/resources/Tray* app.asar.contents/resources/
cp ../lib/net45/resources/*-*.json app.asar.contents/resources/i18n/

# Repackage
asar pack app.asar.contents app.asar

# Copy to AppDir
mkdir -p "$APP_DIR/usr/lib/claude-desktop"
cp app.asar "$APP_DIR/usr/lib/claude-desktop/"
cp -r app.asar.unpacked "$APP_DIR/usr/lib/claude-desktop/"

# Create native module directory and stub
mkdir -p "$APP_DIR/usr/lib/claude-desktop/app.asar.unpacked/node_modules/claude-native"
cat > "$APP_DIR/usr/lib/claude-desktop/app.asar.unpacked/node_modules/claude-native/index.js" << 'EOFSTUB2'
const KeyboardKey = {
  Backspace: 43, Tab: 280, Enter: 261, Shift: 272, Control: 61, Alt: 40,
  CapsLock: 56, Escape: 85, Space: 276, PageUp: 251, PageDown: 250,
  End: 83, Home: 154, LeftArrow: 175, UpArrow: 282, RightArrow: 262,
  DownArrow: 81, Delete: 79, Meta: 187
};

Object.freeze(KeyboardKey);

module.exports = {
  getWindowsVersion: () => "10.0.0",
  setWindowEffect: () => {}, removeWindowEffect: () => {}, getIsMaximized: () => false,
  flashFrame: () => {}, clearFlashFrame: () => {}, showNotification: () => {},
  setProgressBar: () => {}, clearProgressBar: () => {}, setOverlayIcon: () => {},
  clearOverlayIcon: () => {}, KeyboardKey
};
EOFSTUB2

# Copy Electron if bundled
if [ "$ELECTRON_BUNDLED" -eq 1 ] && [ -d "$(pwd)/../node_modules/electron" ]; then
    mkdir -p "$APP_DIR/usr/lib/claude-desktop/node_modules"
    cp -r "$(pwd)/../node_modules/electron" "$APP_DIR/usr/lib/claude-desktop/node_modules/"
    echo "✓ Bundled Electron copied to AppDir"
fi

# Create AppRun for Fedora Asahi
cat > "$APP_DIR/AppRun" << 'EOFRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"

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

exec "$ELECTRON" --no-sandbox "$HERE/usr/lib/claude-desktop/app.asar" "$@"
EOFRUN
chmod +x "$APP_DIR/AppRun"

# Create desktop entry
cat > "$APP_DIR/claude-desktop.desktop" << EOFDESKTOP
[Desktop Entry]
Name=Claude Desktop
Comment=AI Assistant by Anthropic
Exec=AppRun %U
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Office;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
StartupNotify=true
Keywords=AI;Assistant;Chat;Anthropic;Claude;
X-AppImage-Version=$VERSION
X-AppImage-Name=Claude Desktop
EOFDESKTOP

# Build AppImage
echo "=== Building AppImage ==="
cd "$WORK_DIR"
APPIMAGE_FILE="Claude_Desktop-${VERSION}-aarch64.AppImage"

# Create an elf binary indicator for architecture detection
mkdir -p "$APP_DIR/usr/bin"
echo -e '#!/bin/bash\necho "Claude Desktop for ARM64"' > "$APP_DIR/usr/bin/claude-desktop"
chmod +x "$APP_DIR/usr/bin/claude-desktop"

# Try multiple approaches to build the AppImage
echo "Attempting AppImage build with ARCH=aarch64..."
if env ARCH=aarch64 "$APP_IMAGE_TOOL" "$APP_DIR" "$APPIMAGE_FILE"; then
    echo "✅ AppImage built successfully with ARCH=aarch64"
elif env ARCH=arm64 "$APP_IMAGE_TOOL" "$APP_DIR" "$APPIMAGE_FILE"; then
    echo "✅ AppImage built successfully with ARCH=arm64"
else
    echo "❌ Standard AppImage build failed, will be handled by manual builder"
    cd "$CURRENT_DIR"
    exit 1
fi

if [ -f "$APPIMAGE_FILE" ]; then
    chmod +x "$APPIMAGE_FILE"
    mv "$APPIMAGE_FILE" "$CURRENT_DIR/"
    echo "✅ Success! AppImage created: $APPIMAGE_FILE"
    cd "$CURRENT_DIR"
    rm -rf build
    
    # Test the AppImage
    echo "Testing AppImage..."
    if "./$APPIMAGE_FILE" --version 2>/dev/null || "./$APPIMAGE_FILE" --help 2>/dev/null; then
        echo "✅ AppImage appears to be working"
    else
        echo "⚠️  AppImage created but may need testing"
    fi
else
    echo "❌ AppImage file not found after build"
    cd "$CURRENT_DIR"
    exit 1
fi
