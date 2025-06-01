# Claude Desktop AppImage Builder

**Unofficial AppImage build scripts for running Claude Desktop on Linux systems, with optimized support for ARM64/aarch64 architectures including Apple Silicon Macs running Asahi Linux.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE-MIT)
[![Architecture](https://img.shields.io/badge/Architecture-x86__64%20%7C%20aarch64-blue)](#supported-architectures)
[![Distribution](https://img.shields.io/badge/Distro-Ubuntu%20%7C%20Fedora%20%7C%20Debian-green)](#supported-distributions)

> **⚠️ DISCLAIMER**: This is an **UNOFFICIAL** build script. For official support, please contact Anthropic. Report issues with this build process here, not to Anthropic.

## ✨ Features

- **🚀 No sudo required** for AppImage execution (dependencies may need system installation)
- **💾 Persistent data storage** - your conversations and settings are saved
- **🎯 Multi-architecture support** - optimized for both x86_64 and ARM64/aarch64
- **🖥️ Full desktop integration** - system tray, keyboard shortcuts (Ctrl+Alt+Space), notifications
- **🔌 MCP Protocol support** - Model Context Protocol for enhanced functionality
- **📱 Native Linux experience** - proper window management and desktop environment integration

## 🖼️ Screenshots

### Main Interface with MCP Support
![Claude Desktop Interface](https://github.com/user-attachments/assets/93080028-6f71-48bd-8e59-5149d148cd45)

### Quick Access Popup (Ctrl+Alt+Space)
![Quick Access Popup](https://github.com/user-attachments/assets/1deb4604-4c06-4e4b-b63f-7f6ef9ef28c1)

### System Tray Integration (KDE)
![System Tray](https://github.com/user-attachments/assets/ba209824-8afb-437c-a944-b53fd9ecd559)

## 🚀 Quick Start

### One-Command Build

```bash
# Clone the repository
git clone https://github.com/yourusername/claude-desktop-to-appimage.git
cd claude-desktop-to-appimage

# Build the AppImage (auto-detects your system)
./build-appimage.sh

# Run Claude Desktop
./Claude_Desktop-0.9.3-aarch64.AppImage
```

### Add Data Persistence

```bash
# Make your data persistent across runs
./add_persistence_simple.sh

# Run the persistent version
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage
```

## 📋 System Requirements

### Supported Architectures
- **x86_64** (Intel/AMD 64-bit)
- **aarch64/ARM64** (Apple Silicon, Raspberry Pi 4+, other ARM64 devices)

### Supported Distributions
- **Ubuntu** 20.04+ and derivatives
- **Fedora** 35+ (optimized scripts for Fedora Asahi)
- **Debian** 11+ and derivatives
- **Arch Linux** and derivatives
- Most other Linux distributions with required dependencies
### Dependencies
- **Node.js** ≥ 12.0.0 and npm
- **7zip** (`p7zip` package)
- **wget** 
- **icoutils** (wrestool, icotool)
- **ImageMagick** (convert command)
- **FUSE** support (usually pre-installed)

*The build script will check for missing dependencies and guide you through installation.*

## 🔧 Advanced Usage

### Command Line Options

```bash
# Basic usage
./build-appimage.sh

# Custom Claude download URL
./build-appimage.sh --claude-download-url "https://custom-url/claude.exe"

# Use custom appimagetool path
./build-appimage.sh --appimagetool /path/to/appimagetool

# Bundle Electron with AppImage
./build-appimage.sh --bundle-electron

# Show help
./build-appimage.sh --help
```

### Platform-Specific Builders

For ARM64 systems (especially Fedora Asahi):
```bash
./fedora_asahi_build_script.sh
```

For manual building when automated tools fail:
```bash
./manual_appimage_builder.sh
```

### Installation Options

#### Option 1: Portable Usage
```bash
# Just run directly - no installation needed
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage
```

#### Option 2: User Installation
```bash
# Install to user bin directory
mkdir -p ~/.local/bin
cp Claude_Desktop-0.9.3-aarch64-persistent.AppImage ~/.local/bin/claude-desktop
chmod +x ~/.local/bin/claude-desktop

# Add to PATH if needed
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Now run from anywhere
claude-desktop
```

## 📁 Data Storage Locations

Your Claude data persists in standard XDG directories:

- **Configuration & Login**: `~/.config/Claude/`
- **Conversations & Files**: `~/.local/share/Claude/`
- **Cache & Temporary Files**: `~/.cache/Claude/`
- **MCP Configuration**: `~/.config/Claude/claude_desktop_config.json`

## 🔧 Technical Details

### How It Works

Claude Desktop is an Electron application packaged as a Windows executable. This project:

1. **Downloads** the official Windows installer from Anthropic
2. **Extracts** the app.asar archive containing the application code
3. **Replaces** Windows-specific native modules with Linux-compatible implementations
4. **Repackages** everything into a proper Linux AppImage
5. **Adds** desktop integration and persistent data storage

### Architecture Support

The main challenge for ARM64 builds is the `claude-native-bindings` module, which provides:
- Keyboard input handling with correct key mappings
- Window management and system tray integration
- Monitor information and system-level functionality

Our build scripts replace this with a Linux-compatible implementation that maintains the same API while providing native Linux functionality.

### Native Module Implementation

```javascript
// Stub implementation for claude-native-bindings
const KeyboardKey = {
  Backspace: 43, Tab: 280, Enter: 261, Shift: 272, Control: 61, Alt: 40,
  CapsLock: 56, Escape: 85, Space: 276, PageUp: 251, PageDown: 250,
  End: 83, Home: 154, LeftArrow: 175, UpArrow: 282, RightArrow: 262,
  DownArrow: 81, Delete: 79, Meta: 187
};

module.exports = {
  getWindowsVersion: () => "10.0.0",
  setWindowEffect: () => {}, removeWindowEffect: () => {},
  flashFrame: () => {}, showNotification: () => {},
  KeyboardKey
};
```

## 🛠️ Troubleshooting

### Common Issues

#### AppImage Won't Start
```bash
# Make executable
chmod +x Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Check dependencies
ldd Claude_Desktop-0.9.3-aarch64-persistent.AppImage

# Try verbose mode
./Claude_Desktop-0.9.3-aarch64-persistent.AppImage --verbose
```

#### FUSE Issues (Common on Fedora)
```bash
# Check FUSE device
ls -la /dev/fuse

# Fix permissions
sudo chmod 666 /dev/fuse
sudo modprobe fuse

# Create persistent fix
echo 'KERNEL=="fuse", MODE="0666"' | sudo tee /etc/udev/rules.d/99-fuse.rules
```

#### Data Not Persisting
```bash
# Check directories exist
ls -la ~/.config/Claude/ ~/.local/share/Claude/

# Create manually if needed
mkdir -p ~/.config/Claude ~/.local/share/Claude ~/.cache/Claude

# Use persistent version
./add_persistence_simple.sh
```

#### ARM64 Build Failures
```bash
# Use specialized builder
./fedora_asahi_build_script.sh

# If that fails, try manual approach
./manual_appimage_builder.sh
```

### Getting Help

Check the detailed troubleshooting guides:
- [Complete Usage Guide](complete_usage_guide.md) - Comprehensive setup and usage instructions
- [Technical Documentation](claude_appimage_documentation.md) - In-depth technical details
- [Project Structure](PROJECT_STRUCTURE.md) - Understanding the codebase

## 📦 Build Artifacts

After a successful build, you'll have:

```
Claude_Desktop-0.9.3-aarch64.AppImage          # Standard version
Claude_Desktop-0.9.3-aarch64-persistent.AppImage  # With data persistence (recommended)
```

## 🤝 Contributing

We welcome contributions! Areas for improvement:

- **Platform support** - test on more distributions
- **Architecture support** - RISC-V, other architectures  
- **Build process** - more robust error handling
- **Documentation** - better guides and examples

### Development Setup

```bash
git clone https://github.com/yourusername/claude-desktop-to-appimage.git
cd claude-desktop-to-appimage

# Make scripts executable
chmod +x *.sh

# Test build process
./build-appimage.sh --help
```

## 📊 Project Status

This project successfully creates working Claude Desktop AppImages for:

- ✅ **Ubuntu 20.04+** (x86_64, aarch64)
- ✅ **Fedora 35+** (x86_64, aarch64) 
- ✅ **Fedora Asahi Remix** (Apple Silicon)
- ✅ **Debian 11+** (x86_64, aarch64)
- 🔄 **Arch Linux** (testing in progress)

Features confirmed working:
- ✅ Main application functionality
- ✅ Data persistence across sessions
- ✅ System tray integration
- ✅ Keyboard shortcuts (Ctrl+Alt+Space)
- ✅ MCP protocol support
- ✅ Desktop integration
- ✅ Notifications

## 📄 License & Legal

**Build Scripts**: MIT License - see [LICENSE-MIT](LICENSE-MIT)

**Claude Desktop Application**: Subject to [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms). This project only provides build scripts; the actual Claude Desktop application is downloaded from Anthropic's official servers.

## 🙏 Acknowledgments

- **Anthropic** for creating Claude Desktop
- **[@aaddrick](https://github.com/aaddrick/claude-desktop-debian)** for the original Debian packaging inspiration
- **AppImage Project** for the AppImage format and tools
- **Asahi Linux** for making Linux possible on Apple Silicon
- **Fedora Project** for Fedora Asahi Remix

## 🔗 Related Projects

- [aaddrick/claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian) - Original Debian packaging
- [AppImage/AppImageKit](https://github.com/AppImage/AppImageKit) - AppImage creation tools
- [AsahiLinux/asahi-installer](https://github.com/AsahiLinux/asahi-installer) - Asahi Linux installer

---

**Questions?** Check our [documentation](claude_appimage_documentation.md) or [open an issue](https://github.com/yourusername/claude-desktop-to-appimage/issues).

**Found this helpful?** Give it a ⭐ and help others discover it!
