#!/bin/bash
# Fix Claude Desktop Entry

echo "Fixing Claude Desktop entry..."

# Get the actual home directory path
HOME_DIR="$HOME"

# Remove old desktop entry
rm -f ~/.local/share/applications/claude-desktop.desktop

# Create corrected desktop entry with absolute path
cat > ~/.local/share/applications/claude-desktop.desktop << EOF
[Desktop Entry]
Name=Claude Desktop
Comment=AI Assistant by Anthropic
Exec=$HOME_DIR/.local/bin/claude-desktop.AppImage %U
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Office;Productivity;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
StartupNotify=true
Keywords=AI;Assistant;Chat;Anthropic;Claude;
EOF

# Make sure the AppImage exists and is executable
if [ ! -f "$HOME_DIR/.local/bin/claude-desktop.AppImage" ]; then
    echo "❌ AppImage not found at: $HOME_DIR/.local/bin/claude-desktop.AppImage"
    
    # Check if it exists in current directory
    if [ -f "Claude_Desktop-0.9.3-aarch64-persistent.AppImage" ]; then
        echo "Found AppImage in current directory. Moving it..."
        mkdir -p ~/.local/bin
        cp Claude_Desktop-0.9.3-aarch64-persistent.AppImage ~/.local/bin/claude-desktop.AppImage
        chmod +x ~/.local/bin/claude-desktop.AppImage
        echo "✓ Moved AppImage to ~/.local/bin/"
    else
        echo "Please ensure the AppImage is at: $HOME_DIR/.local/bin/claude-desktop.AppImage"
        exit 1
    fi
fi

chmod +x "$HOME_DIR/.local/bin/claude-desktop.AppImage"

# Update desktop database
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

# Test the desktop entry
echo "Testing desktop entry..."
desktop-file-validate ~/.local/share/applications/claude-desktop.desktop

if [ $? -eq 0 ]; then
    echo "✅ Desktop entry is valid"
else
    echo "⚠️  Desktop entry validation failed, but it may still work"
fi

# Test execution
echo "Testing AppImage execution..."
if "$HOME_DIR/.local/bin/claude-desktop.AppImage" --version 2>/dev/null; then
    echo "✅ AppImage executes successfully"
else
    echo "⚠️  AppImage test failed, but it may still work in GUI mode"
fi

echo ""
echo "Desktop entry fixed!"
echo "Path: ~/.local/share/applications/claude-desktop.desktop"
echo "Exec: $HOME_DIR/.local/bin/claude-desktop.AppImage"
echo ""
echo "Try finding 'Claude Desktop' in your application menu now."