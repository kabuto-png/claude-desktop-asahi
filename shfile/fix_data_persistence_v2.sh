#!/bin/bash
set -e

echo "=== Fixing Claude AppImage Data Persistence (v2) ==="

# Check if AppImage exists
APPIMAGE_NAME="Claude_Desktop-0.9.3-aarch64.AppImage"
if [ ! -f "$APPIMAGE_NAME" ]; then
    echo "❌ Claude AppImage not found: $APPIMAGE_NAME"
    echo "Available AppImages:"
    ls -la *.AppImage 2>/dev/null || echo "No AppImage files found"
    exit 1
fi

echo "Found AppImage: $APPIMAGE_NAME"

# Clean up any previous extraction
rm -rf squashfs-root

# Extract the AppImage for modification
echo "Extracting AppImage for modification..."
"./$APPIMAGE_NAME" --appimage-extract

# Verify extraction worked
if [ ! -d "squashfs-root" ]; then
    echo "❌ AppImage extraction failed"
    exit 1
fi

echo "✓ AppImage extracted successfully"

# Get current directory for absolute paths
WORK_DIR="$(pwd)"
SQUASHFS_ROOT="$WORK_DIR/squashfs-root"

echo "Working in: $WORK_DIR"
echo "SquashFS root: $SQUASHFS_ROOT"

# Backup original AppRun
cp "$SQUASHFS_ROOT/AppRun" "$SQUASHFS_ROOT/AppRun.backup"
echo "✓ Backed up original AppRun"

# Create new AppRun with proper data persistence
echo "Creating new AppRun with data persistence..."
cat > "$SQUASHFS_ROOT/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"

# Set up proper data directories for persistence
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Create Claude data directories if they don't exist
mkdir -p "$XDG_CONFIG_HOME/Claude"
mkdir -p "$XDG_DATA_HOME/Claude"
mkdir -p "$XDG_CACHE_HOME/Claude"

# For Fedora Asahi ARM64
export PATH="$HERE/usr/bin:$HERE/usr/lib/claude-desktop/node_modules/electron/dist:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/lib:$LD_LIBRARY_PATH"

# Ensure proper permissions for data directories
chmod 755 "$XDG_CONFIG_HOME/Claude" 2>/dev/null || true
chmod 755 "$XDG_DATA_HOME/Claude" 2>/dev/null || true
chmod 755 "$XDG_CACHE_HOME/Claude" 2>/dev/null || true

# Find Electron
if [ -f "$HERE/usr/lib/claude-desktop/node_modules/electron/dist/electron" ]; then
    ELECTRON="$HERE/usr/lib/claude-desktop/node_modules/electron/dist/electron"
elif command -v electron &>/dev/null; then
    ELECTRON="electron"
else
    echo "Error: Electron not found"
    exit 1
fi

# Launch with proper data persistence flags
exec "$ELECTRON" \
    --no-sandbox \
    --user-data-dir="$XDG_CONFIG_HOME/Claude" \
    "$HERE/usr/lib/claude-desktop/app.asar" \
    "$@"
EOF

chmod +x "$SQUASHFS_ROOT/AppRun"
echo "✓ Created new AppRun with persistence"

# Check if asar tools are available
if ! command -v npx &>/dev/null; then
    echo "❌ npx not found. Installing nodejs..."
    sudo dnf install -y nodejs npm
fi

# Navigate to the app directory
CLAUDE_APP_DIR="$SQUASHFS_ROOT/usr/lib/claude-desktop"
cd "$CLAUDE_APP_DIR"

echo "Modifying application for better data persistence..."

# Backup original asar
if [ -f "app.asar" ]; then
    cp app.asar app.asar.backup
    echo "✓ Backed up app.asar"
else
    echo "❌ app.asar not found in $CLAUDE_APP_DIR"
    ls -la
    exit 1
fi

# Check if we have asar command
if ! command -v asar &>/dev/null; then
    echo "Installing asar globally..."
    npm install -g asar
fi

# Extract the asar
rm -rf app.asar.contents
npx asar extract app.asar app.asar.contents
echo "✓ Extracted app.asar"

# Check package.json for main entry point
if [ ! -f "app.asar.contents/package.json" ]; then
    echo "❌ package.json not found in extracted asar"
    exit 1
fi

# Get the main entry point
MAIN_FILE=$(node -p "require('./app.asar.contents/package.json').main" 2>/dev/null || echo "main.js")
echo "Main entry point: $MAIN_FILE"

# Create a persistence patch
cat > app.asar.contents/persistence-patch.js << 'EOFJS'
// Persistence patch for Claude Desktop AppImage
const { app } = require('electron');
const path = require('path');
const os = require('os');

// Only run this patch in the main process
if (process.type === 'browser') {
    console.log('Applying Claude persistence patch...');
    
    // Ensure proper user data directory
    const homeDir = os.homedir();
    const configDir = process.env.XDG_CONFIG_HOME || path.join(homeDir, '.config');
    const dataDir = process.env.XDG_DATA_HOME || path.join(homeDir, '.local', 'share');
    
    const claudeConfigDir = path.join(configDir, 'Claude');
    const claudeDataDir = path.join(dataDir, 'Claude');
    
    // Set app paths before app ready event
    try {
        app.setPath('userData', claudeConfigDir);
        app.setPath('appData', claudeDataDir);
        app.setPath('logs', path.join(claudeDataDir, 'logs'));
        app.setPath('sessionData', path.join(claudeConfigDir, 'sessions'));
        
        console.log('Claude data persistence configured:');
        console.log('  Config:', claudeConfigDir);
        console.log('  Data:', claudeDataDir);
    } catch (error) {
        console.warn('Could not set app paths:', error.message);
    }
    
    // Create directories
    const fs = require('fs');
    [claudeConfigDir, claudeDataDir].forEach(dir => {
        try {
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true, mode: 0o755 });
                console.log('Created directory:', dir);
            }
        } catch (error) {
            console.warn('Could not create directory:', dir, error.message);
        }
    });
}
EOFJS

echo "✓ Created persistence patch"

# Modify the main entry point to include persistence patch
if [ -f "app.asar.contents/$MAIN_FILE" ]; then
    # Create a new main file with persistence patch
    cat > temp_main.js << 'EOFMAIN'
// Load persistence patch first
try {
    require('./persistence-patch.js');
} catch (error) {
    console.warn('Could not load persistence patch:', error.message);
}

// Load original main file
EOFMAIN
    cat "app.asar.contents/$MAIN_FILE" >> temp_main.js
    mv temp_main.js "app.asar.contents/$MAIN_FILE"
    echo "✓ Added persistence patch to main process"
else
    echo "⚠️  Main file not found: $MAIN_FILE"
fi

# Repackage the asar
npx asar pack app.asar.contents app.asar
echo "✓ Repackaged app.asar"

# Return to work directory
cd "$WORK_DIR"

# Rebuild the AppImage
echo "Rebuilding AppImage with persistence fixes..."

# Install squashfs-tools if not present
if ! command -v mksquashfs &>/dev/null; then
    echo "Installing squashfs-tools..."
    sudo dnf install -y squashfs-tools
fi

# Download runtime if not present
if [ ! -f runtime-aarch64 ]; then
    echo "Downloading ARM64 runtime..."
    wget -O runtime-aarch64 https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-aarch64
    chmod +x runtime-aarch64
fi

# Verify squashfs-root still exists
if [ ! -d "$SQUASHFS_ROOT" ]; then
    echo "❌ SquashFS root directory missing: $SQUASHFS_ROOT"
    exit 1
fi

# Create new AppImage with persistence
echo "Creating SquashFS filesystem..."
mksquashfs "$SQUASHFS_ROOT" filesystem-fixed.squashfs -root-owned -noappend -comp xz

echo "Assembling AppImage..."
cat runtime-aarch64 filesystem-fixed.squashfs > Claude_Desktop-0.9.3-aarch64-persistent.AppImage
chmod +x Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Cleanup
echo "Cleaning up temporary files..."
rm -rf squashfs-root filesystem-fixed.squashfs

echo ""
echo "✅ SUCCESS! Created persistent AppImage: Claude_Desktop-0.9.3-aarch64-persistent.AppImage"
echo ""
echo "Your data will now be stored in:"
echo "  Configuration: ~/.config/Claude/"
echo "  App Data:      ~/.local/share/Claude/"
echo "  Cache:         ~/.cache/Claude/"
echo ""
echo "Test the new AppImage:"
echo "./Claude_Desktop-0.9.3-aarch64-persistent.AppImage"
echo ""
echo "The original AppImage is preserved as: $APPIMAGE_NAME"