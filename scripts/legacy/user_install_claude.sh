#!/bin/bash
# User installation for Claude Desktop

echo "Installing Claude Desktop for current user..."

# Create user directories
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/applications
mkdir -p ~/.local/share/icons/hicolor/256x256/apps

# Move AppImage to user location
cp Claude_Desktop-0.9.3-aarch64-persistent.AppImage ~/.local/bin/claude-desktop.AppImage
chmod +x ~/.local/bin/claude-desktop.AppImage

# Extract and install icon
~/.local/bin/claude-desktop.AppImage --appimage-extract usr/share/icons/hicolor/256x256/apps/claude-desktop.png
cp squashfs-root/usr/share/icons/hicolor/256x256/apps/claude-desktop.png ~/.local/share/icons/hicolor/256x256/apps/
rm -rf squashfs-root

# Create user desktop entry
cat > ~/.local/share/applications/claude-desktop.desktop << 'EOF'
[Desktop Entry]
Name=Claude Desktop
Comment=AI Assistant by Anthropic
Exec=%h/.local/bin/claude-desktop.AppImage %U
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Office;Productivity;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
StartupNotify=true
Keywords=AI;Assistant;Chat;Anthropic;Claude;
EOF

# Update user desktop database
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

# Add to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "Added ~/.local/bin to PATH in ~/.bashrc"
    echo "Run: source ~/.bashrc or open a new terminal"
fi

echo "✅ Claude Desktop installed for user!"
echo "You can now:"
echo "  1. Find it in your application menu"
echo "  2. Run 'claude-desktop.AppImage' from terminal"
echo "  3. Run from ~/.local/bin/claude-desktop.AppImage"