#!/bin/bash
set -e

echo "=== Fixing Claude AppImage Data Persistence ==="

# Check if AppImage exists
if [ ! -f "Claude_Desktop-0.9.3-aarch64.AppImage" ]; then
    echo "❌ Claude AppImage not found. Build it first."
    exit 1
fi

# Extract the AppImage for modification
echo "Extracting AppImage for modification..."
./Claude_Desktop-0.9.3-aarch64.AppImage --appimage-extract

# Backup original AppRun
cp squashfs-root/AppRun squashfs-root/AppRun.backup

# Create new AppRun with proper data persistence
cat > squashfs-root/AppRun << 'EOF'
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
chmod 755 "$XDG_CONFIG_HOME/Claude"
chmod 755 "$XDG_DATA_HOME/Claude"
chmod 755 "$XDG_CACHE_HOME/Claude"

echo "Claude data will be stored in:"
echo "  Config: $XDG_CONFIG_HOME/Claude"
echo "  Data: $XDG_DATA_HOME/Claude"
echo "  Cache: $XDG_CACHE_HOME/Claude"

# Find Electron
if [ -f "$HERE/usr/lib/claude-desktop/node_modules/electron/dist/electron" ]; then
    ELECTRON="$HERE/usr/lib/claude-desktop/node_modules/electron/dist/electron"
elif command -v electron &>/dev/null; then
    ELECTRON="electron"
else
    echo "Error: Electron not found"
    exit 1
fi

# Set Electron user data directory explicitly
export ELECTRON_USER_DATA="$XDG_CONFIG_HOME/Claude"

# Launch with proper data persistence flags
exec "$ELECTRON" \
    --no-sandbox \
    --user-data-dir="$XDG_CONFIG_HOME/Claude" \
    --app-data-path="$XDG_DATA_HOME/Claude" \
    "$HERE/usr/lib/claude-desktop/app.asar" \
    "$@"
EOF

chmod +x squashfs-root/AppRun

# Also modify the main application to ensure data persistence
echo "Modifying application for better data persistence..."

# Extract and modify app.asar
cd squashfs-root/usr/lib/claude-desktop
cp app.asar app.asar.backup

# Extract the asar
npx asar extract app.asar app.asar.contents

# Create a persistence patch for the main process
cat > app.asar.contents/persistence-patch.js << 'EOFJS'
// Persistence patch for Claude Desktop AppImage
const { app } = require('electron');
const path = require('path');
const os = require('os');

// Ensure proper user data directory
const homeDir = os.homedir();
const configDir = process.env.XDG_CONFIG_HOME || path.join(homeDir, '.config');
const dataDir = process.env.XDG_DATA_HOME || path.join(homeDir, '.local', 'share');

const claudeConfigDir = path.join(configDir, 'Claude');
const claudeDataDir = path.join(dataDir, 'Claude');

// Set app paths early
app.setPath('userData', claudeConfigDir);
app.setPath('appData', claudeDataDir);
app.setPath('logs', path.join(claudeDataDir, 'logs'));
app.setPath('sessionData', path.join(claudeConfigDir, 'sessions'));

// Create directories
const fs = require('fs');
[claudeConfigDir, claudeDataDir].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true, mode: 0o755 });
    }
});

console.log('Claude data persistence configured:');
console.log('  Config:', claudeConfigDir);
console.log('  Data:', claudeDataDir);
EOFJS

# Modify the main entry point to include persistence patch
MAIN_FILE=$(node -p "require('./app.asar.contents/package.json').main")
if [ -f "app.asar.contents/$MAIN_FILE" ]; then
    # Add persistence patch to the top of main file
    echo "require('./persistence-patch.js');" > temp_main.js
    cat "app.asar.contents/$MAIN_FILE" >> temp_main.js
    mv temp_main.js "app.asar.contents/$MAIN_FILE"
    echo "✓ Added persistence patch to main process"
fi

# Repackage the asar
npx asar pack app.asar.contents app.asar

cd ../../..

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
fi

# Create new AppImage with persistence
mksquashfs squashfs-root filesystem-fixed.squashfs -root-owned -noappend -comp xz
cat runtime-aarch64 filesystem-fixed.squashfs > Claude_Desktop-0.9.3-aarch64-persistent.AppImage
chmod +x Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Cleanup
rm -rf squashfs-root filesystem-fixed.squashfs

echo "✅ Created persistent AppImage: Claude_Desktop-0.9.3-aarch64-persistent.AppImage"
echo ""
echo "Data will be stored in:"
echo "  ~/.config/Claude/    (settings, sessions)"
echo "  ~/.local/share/Claude/  (app data, files)"
echo "  ~/.cache/Claude/     (temporary files)"
echo ""
echo "Test the new AppImage:"
echo "./Claude_Desktop-0.9.3-aarch64-persistent.AppImage"
EOF