#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# One-line installer for Claude Desktop AppImage (aarch64)
# Usage: curl -fsSL https://raw.githubusercontent.com/kabuto-png/claude-desktop-to-appimage/main/install.sh | bash
set -e

REPO="kabuto-png/claude-desktop-to-appimage"
INSTALL_DIR="${CLAUDE_INSTALL_DIR:-$HOME/.local/bin}"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
  error "This installer is for aarch64 (ARM64) only. Detected: $ARCH"
fi

# Check dependencies
for cmd in curl jq; do
  command -v "$cmd" &>/dev/null || error "Missing dependency: $cmd"
done

info "Claude Desktop AppImage Installer (aarch64)"

# Get latest release
info "Fetching latest release..."
RELEASE=$(curl -sf "https://api.github.com/repos/${REPO}/releases/latest") || error "Could not fetch releases"
VERSION=$(echo "$RELEASE" | jq -r '.tag_name' | sed 's/^v//')
DOWNLOAD_URL=$(echo "$RELEASE" | jq -r '.assets[] | select(.name | endswith("aarch64.AppImage")) | .browser_download_url' | head -1)
CHECKSUM_URL=$(echo "$RELEASE" | jq -r '.assets[] | select(.name == "SHA256SUMS.txt") | .browser_download_url' | head -1)

if [ -z "$DOWNLOAD_URL" ]; then
  error "No aarch64 AppImage found in latest release"
fi

APPIMAGE_NAME="Claude_Desktop-${VERSION}-aarch64.AppImage"
info "Latest version: v${VERSION}"

# Check if already installed
if [ -f "$INSTALL_DIR/$APPIMAGE_NAME" ]; then
  warn "v${VERSION} already installed at $INSTALL_DIR/$APPIMAGE_NAME"
  echo -n "Reinstall? [y/N] "
  read -r answer
  [ "$answer" != "y" ] && [ "$answer" != "Y" ] && exit 0
fi

# Create directories
mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" "$ICON_DIR"

# Download
info "Downloading $APPIMAGE_NAME..."
TEMP_FILE=$(mktemp /tmp/claude-desktop-XXXXX.AppImage)
trap 'rm -f "$TEMP_FILE" /tmp/claude-checksums-*.txt' EXIT
curl -L -f --progress-bar -o "$TEMP_FILE" "$DOWNLOAD_URL" || error "Download failed"

# Verify checksum
if [ -n "$CHECKSUM_URL" ]; then
  info "Verifying checksum..."
  CHECKSUM_FILE=$(mktemp /tmp/claude-checksums-XXXXX.txt)
  curl -sf -o "$CHECKSUM_FILE" "$CHECKSUM_URL"
  EXPECTED=$(grep "$APPIMAGE_NAME" "$CHECKSUM_FILE" | awk '{print $1}')
  ACTUAL=$(sha256sum "$TEMP_FILE" | awk '{print $1}')
  if [ -n "$EXPECTED" ] && [ "$EXPECTED" != "$ACTUAL" ]; then
    error "Checksum mismatch! Expected: $EXPECTED Got: $ACTUAL"
  fi
  info "Checksum verified"
fi

# Install
info "Installing to $INSTALL_DIR/"
mv "$TEMP_FILE" "$INSTALL_DIR/$APPIMAGE_NAME"
chmod +x "$INSTALL_DIR/$APPIMAGE_NAME"

# Remove old versions
for old in "$INSTALL_DIR"/Claude_Desktop-*-aarch64.AppImage; do
  [ "$old" != "$INSTALL_DIR/$APPIMAGE_NAME" ] && [ -f "$old" ] && rm -f "$old" && info "Removed old: $(basename "$old")"
done

# Create symlink
ln -sf "$INSTALL_DIR/$APPIMAGE_NAME" "$INSTALL_DIR/claude-desktop"

# Create .desktop entry
cat > "$DESKTOP_DIR/claude-desktop.desktop" << EOF
[Desktop Entry]
Name=Claude Desktop
Comment=Claude AI Assistant
Exec=$INSTALL_DIR/claude-desktop --no-sandbox %u
Icon=claude-desktop
Type=Application
Categories=Network;Chat;
StartupWMClass=Claude
EOF

info "Desktop entry created"

# Check PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  warn "$INSTALL_DIR is not in your PATH"
  warn "Add to your shell config: export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo ""
info "Claude Desktop v${VERSION} installed successfully!"
echo ""
echo "  Run:  claude-desktop"
echo "  Or:   $INSTALL_DIR/$APPIMAGE_NAME"
echo ""
echo "  Data: ~/.config/Claude/ (config)"
echo "        ~/.local/share/Claude/ (conversations)"
echo ""
