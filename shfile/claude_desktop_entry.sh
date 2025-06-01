#!/bin/bash
# Install Claude Desktop Entry

echo "Creating desktop entry for Claude Desktop..."

# Extract icon from AppImage
/opt/claude-desktop/claude-desktop.AppImage --appimage-extract usr/share/icons/hicolor/256x256/apps/claude-desktop.png

# Install icon
sudo mkdir -p /usr/share/icons/hicolor/256x256/apps
sudo cp squashfs-root/usr/share/icons/hicolor/256x256/apps/claude-desktop.png /usr/share/icons/hicolor/256x256/apps/
sudo chmod 644 /usr/share/icons/hicolor/256x256/apps/claude-desktop.png

# Install other icon sizes
for size in 16 24 32 48 64 128 256; do
    if [ -f "squashfs-root/usr/share/icons/hicolor/${size}x${size}/apps/claude-desktop.png" ]; then
        sudo mkdir -p "/usr/share/icons/hicolor/${size}x${size}/apps"
        sudo cp "squashfs-root/usr/share/icons/hicolor/${size}x${size}/apps/claude-desktop.png" "/usr/share/icons/hicolor/${size}x${size}/apps/"
        sudo chmod 644 "/usr/share/icons/hicolor/${size}x${size}/apps/claude-desktop.png"
    fi
done

# Clean up extracted files
rm -rf squashfs-root

# Create desktop entry
sudo tee /usr/share/applications/claude-desktop.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Claude Desktop
Comment=AI Assistant by Anthropic
Exec=/opt/claude-desktop/claude-desktop.AppImage %U
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Office;Productivity;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
StartupNotify=true
Keywords=AI;Assistant;Chat;Anthropic;Claude;
Actions=new-conversation;

[Desktop Action new-conversation]
Name=New Conversation
Exec=/opt/claude-desktop/claude-desktop.AppImage --new-conversation
EOF

# Update desktop database
sudo update-desktop-database /usr/share/applications/
sudo gtk-update-icon-cache /usr/share/icons/hicolor/ -f -t

echo "✅ Desktop entry installed successfully!"
echo "Claude Desktop should now appear in your application menu."