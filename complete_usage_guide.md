# Claude Desktop AppImage - Complete Usage Guide

This guide covers everything you need to know about running your Claude Desktop AppImage on Fedora Asahi.

## Quick Start

### Option 1: Simple Run (Portable)
```bash
# Just run it directly (no installation needed)
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage
```

### Option 2: Install for Current User
```bash
# Install to ~/.local/bin for easy access
mkdir -p ~/.local/bin
cp Claude_Desktop-0.9.3-aarch64-persistent.AppImage ~/.local/bin/claude-desktop
chmod +x ~/.local/bin/claude-desktop

# Add to PATH if not already there
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Now run from anywhere
claude-desktop
```

## Data Storage Locations

Your Claude data persists in these locations:
- **Configuration & Login**: `~/.config/Claude/`
- **Conversations & Files**: `~/.local/share/Claude/`
- **Cache & Temp Files**: `~/.cache/Claude/`

## Desktop Integration

### Create Application Menu Entry
```bash
# Create desktop entry
mkdir -p ~/.local/share/applications
mkdir -p ~/.local/share/icons/hicolor/256x256/apps

# Extract icon from AppImage
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --appimage-extract usr/share/icons/hicolor/256x256/apps/claude-desktop.png
cp squashfs-root/usr/share/icons/hicolor/256x256/apps/claude-desktop.png ~/.local/share/icons/hicolor/256x256/apps/
rm -rf squashfs-root

# Create desktop entry file
cat > ~/.local/share/applications/claude-desktop.desktop << EOF
[Desktop Entry]
Name=Claude Desktop
Comment=AI Assistant by Anthropic
Exec=$HOME/.local/bin/claude-desktop %U
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Office;Productivity;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
StartupNotify=true
Keywords=AI;Assistant;Chat;Anthropic;Claude;
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications/
```

### Create Desktop Shortcut
```bash
# Copy AppImage to Desktop
cp Claude_Desktop-0.9.3-aarch64-persistent.AppImage ~/Desktop/
chmod +x ~/Desktop/Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Or create a launcher script
cat > ~/Desktop/claude-desktop.sh << 'EOF'
#!/bin/bash
cd "$HOME/.local/bin"
./claude-desktop
EOF
chmod +x ~/Desktop/claude-desktop.sh
```

## Troubleshooting

### Common Issues and Solutions

#### 1. AppImage Won't Start
```bash
# Check if file is executable
chmod +x Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Test with verbose output
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --verbose

# Check dependencies
ldd Claude_Desktop-0.9.3-aarch64-persistent.AppImage
```

#### 2. FUSE Issues
```bash
# Check FUSE availability
ls -la /dev/fuse

# Fix FUSE permissions
sudo chmod 666 /dev/fuse
sudo modprobe fuse

# If persistent issues, use extract mode
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --appimage-extract-and-run
```

#### 3. Data Not Persisting
```bash
# Check if directories exist
ls -la ~/.config/Claude/
ls -la ~/.local/share/Claude/

# Create directories manually if needed
mkdir -p ~/.config/Claude ~/.local/share/Claude ~/.cache/Claude
chmod 755 ~/.config/Claude ~/.local/share/Claude ~/.cache/Claude

# Check AppRun script
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --appimage-extract
cat squashfs-root/AppRun | grep -A 10 "XDG_CONFIG_HOME"
rm -rf squashfs-root
```

#### 4. Application Menu Entry Missing
```bash
# Refresh desktop database
update-desktop-database ~/.local/share/applications/

# Update icon cache
gtk-update-icon-cache ~/.local/share/icons/hicolor/ 2>/dev/null || true

# Test desktop entry
desktop-file-validate ~/.local/share/applications/claude-desktop.desktop
```

#### 5. Electron/Sandbox Issues
```bash
# Run with different flags if needed
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --no-sandbox --disable-gpu-sandbox

# Check Electron version (if accessible)
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --version
```

## Advanced Usage

### Running with Custom Flags
```bash
# Disable hardware acceleration
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --disable-gpu

# Enable debug logging
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --enable-logging --log-level=0

# Use different data directory
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --user-data-dir=/path/to/custom/dir
```

### Multiple Instances
```bash
# Run multiple instances with different data directories
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --user-data-dir=~/.config/Claude-Work
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --user-data-dir=~/.config/Claude-Personal
```

### Network Configuration
```bash
# Use proxy
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --proxy-server=http://proxy:8080

# Ignore certificate errors (not recommended for production)
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --ignore-certificate-errors
```

## Backup and Migration

### Backup Your Data
```bash
# Create backup of all Claude data
tar -czf claude-backup-$(date +%Y%m%d).tar.gz \
  ~/.config/Claude \
  ~/.local/share/Claude \
  ~/.cache/Claude

# Backup just important data (exclude cache)
tar -czf claude-data-$(date +%Y%m%d).tar.gz \
  ~/.config/Claude \
  ~/.local/share/Claude
```

### Restore Data
```bash
# Extract backup
tar -xzf claude-backup-20250601.tar.gz -C ~/

# Or restore to different location
mkdir -p /tmp/claude-restore
tar -xzf claude-backup-20250601.tar.gz -C /tmp/claude-restore
```

### Move to Different System
```bash
# On source system - create portable backup
tar -czf claude-portable.tar.gz \
  ~/.config/Claude \
  ~/.local/share/Claude \
  Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# On target system - extract and setup
tar -xzf claude-portable.tar.gz
chmod +x Claude_Desktop-0.9.3-aarch64-persistent.AppImage
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage
```

## System Integration

### Auto-start with System
```bash
# Create autostart entry
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/claude-desktop.desktop << EOF
[Desktop Entry]
Type=Application
Name=Claude Desktop
Exec=$HOME/.local/bin/claude-desktop
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
```

### URL Handler Setup
```bash
# Register claude:// URL handler
xdg-mime default claude-desktop.desktop x-scheme-handler/claude

# Test URL handling
xdg-open "claude://chat/new"
```

## Performance Optimization

### For Low-End Systems
```bash
# Reduce memory usage
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage \
  --memory-pressure-off \
  --max_old_space_size=512 \
  --disable-background-timer-throttling

# Disable animations and effects
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage \
  --disable-animations \
  --disable-smooth-scrolling
```

### For Better Performance
```bash
# Enable hardware acceleration
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage \
  --enable-hardware-acceleration \
  --enable-gpu-rasterization

# Use more CPU cores
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage \
  --max-cpu-cores=4
```

## Updating

### Check for New Versions
```bash
# Manual check at Claude website
echo "Check https://claude.ai/download for new versions"

# Compare your version (if available in help menu)
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --version 2>/dev/null || echo "Version info not available"
```

### Update Process
1. **Download new Claude installer** from official source
2. **Run build scripts again** with new installer
3. **Backup your data** before updating
4. **Replace AppImage** with new version
5. **Test** that data persists correctly

```bash
# Update workflow
cp ~/.config/Claude ~/.config/Claude.backup -r
./fedora_asahi_build_script.sh  # With new installer
./add_persistence_simple.sh
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage  # Test
```

## Uninstallation

### Remove Application
```bash
# Remove AppImage
rm -f ~/.local/bin/claude-desktop
rm -f ~/Desktop/Claude_Desktop-*.AppImage

# Remove desktop integration
rm -f ~/.local/share/applications/claude-desktop.desktop
rm -f ~/.local/share/icons/hicolor/*/apps/claude-desktop.png
rm -f ~/.config/autostart/claude-desktop.desktop

# Update databases
update-desktop-database ~/.local/share/applications/
```

### Remove Data (Optional)
```bash
# CAUTION: This will delete all your Claude conversations and settings!

# Remove all Claude data
rm -rf ~/.config/Claude
rm -rf ~/.local/share/Claude
rm -rf ~/.cache/Claude

# Remove from PATH (edit ~/.bashrc manually)
# Remove line: export PATH="$HOME/.local/bin:$PATH"
```

## Security Considerations

### Data Protection
- Claude data is stored in your home directory with standard file permissions
- No system-wide installation required
- AppImage runs in user space only

### Network Security
- Claude communicates with Anthropic servers over HTTPS
- No local network services are started
- Uses system proxy settings by default

### Sandboxing
- AppImage runs with `--no-sandbox` due to ARM64 compatibility requirements
- Consider running in Flatpak or container for additional isolation if needed

## Getting Help

### Log Files
```bash
# Application logs (if available)
ls -la ~/.config/Claude/logs/

# System logs
journalctl --user -f | grep -i claude

# AppRun debug log
tail -f /tmp/claude-apprun.log
```

### Debug Information
```bash
# System info
uname -a
cat /etc/os-release

# AppImage info
file Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Dependencies
ldd Claude_Desktop-0.9.3-aarch64-persistent.AppImage | head -20
```

### Support Resources
- **AppImage Issues**: Check FUSE setup and ARM64 compatibility
- **Claude Issues**: Contact Anthropic support (for application bugs)
- **Build Issues**: Check the build documentation and dependencies

---

*Last updated: June 2025 for Claude Desktop 0.9.3 on Fedora Asahi Remix 42*

## Quick Reference Commands

```bash
# Basic usage
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Install for user
cp Claude_Desktop-0.9.3-aarch64-persistent.AppImage ~/.local/bin/claude-desktop

# Backup data
tar -czf claude-backup.tar.gz ~/.config/Claude ~/.local/share/Claude

# Troubleshoot FUSE
sudo chmod 666 /dev/fuse && sudo modprobe fuse

# Reset data (CAUTION!)
rm -rf ~/.config/Claude ~/.local/share/Claude ~/.cache/Claude
```