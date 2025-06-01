
# Claude Desktop for Linux (AppImage)

This project was inspired by [aaddrick claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian) for running Claude Desktop natively on Linux. Their work provided valuable insights into the application's structure and the native bindings implementation.

The main changes are:

- No `sudo` required (if some dependencies are missing, it will guide you to install them)
- AppImage generation instead of a `.deb` package


> NOTE:  A big part of this README is taken by [aaddrick claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian) README

***THIS IS AN UNOFFICIAL BUILD SCRIPT!***

If you run into an issue with this build script, make an issue here. Don't bug Anthropic about it - they already have enough on their plates.


# Supports MCP!

Location of the MCP-configuration file is: `~/.config/Claude/claude_desktop_config.json`

![image](https://github.com/user-attachments/assets/93080028-6f71-48bd-8e59-5149d148cd45)

Supports the Ctrl+Alt+Space popup!
![image](https://github.com/user-attachments/assets/1deb4604-4c06-4e4b-b63f-7f6ef9ef28c1)

Supports the Tray menu! (Screenshot of running on KDE)
![image](https://github.com/user-attachments/assets/ba209824-8afb-437c-a944-b53fd9ecd559)

# How to use it

## 1. Download the repo

```bash
# Clone this repository
git clone https://github.com/fsoft72/claude-desktop-to-appimage.git
cd claude-desktop-to-appimage

# Build the AppImage
./build-appimage.sh

# The script will automatically:
# - Check for required dependencies (installation must be done by the user)
# - Download and extract resources from the Windows version
# - Create a proper AppImage
```

Requirements:
- Any Debian-based Linux distribution
- Node.js >= 12.0.0 and npm

## Command line

The script accepts the following command line arguments:

```bash
Usage: ./build-appimage.sh [--appimagetool <path>] [--bundle-electron] [-h|--help]
  --appimagetool <path>   Path to appimagetool (default: /home/fabio/data/opt/appimagetool-x86_64.AppImage)
  --bundle-electron       Bundle Electron with the AppImage (default: 0)
  --claude-download-url <url>  URL to download the Windows installer (default: https://claude.ai/download)
  -h, --help             Show this help message

./build-appimage.sh [--appimagetool <path>] [--bundle-electron] [-h|--help]
```

You can run the script without arguments, and it will use the default values.

```bash
./build-appimage.sh
```

# How it works

Claude Desktop is an Electron application packaged as a Windows executable. Our build script performs several key operations to make it work on Linux:

1. Downloads and extracts the Windows installer
2. Unpacks the app.asar archive containing the application code
3. Replaces the Windows-specific native module with a Linux-compatible implementation
4. Repackages everything into a proper Debian package

The process works because Claude Desktop is largely cross-platform, with only one platform-specific component that needs replacement.

## The Native Module Challenge

The only platform-specific component is a native Node.js module called `claude-native-bindings`. This module provides system-level functionality like:

- Keyboard input handling
- Window management
- System tray integration
- Monitor information

Our build script replaces this Windows-specific module with a Linux-compatible implementation that:

1. Provides the same API surface to maintain compatibility
2. Implements keyboard handling using the correct key codes from the reference implementation
3. Stubs out unnecessary Windows-specific functionality
4. Maintains critical features like the Ctrl+Alt+Space popup and system tray

The replacement module is carefully designed to match the original API while providing Linux-native functionality where needed. This approach allows the rest of the application to run unmodified, believing it's still running on Windows.

## Build Process Details

The build script (`build-appimage.sh`) handles the entire process:

1. Checks for a Debian-based system and required dependencies
2. Downloads the official Windows installer
3. Extracts the application resources
4. Processes icons for Linux desktop integration
5. Unpacks and modifies the app.asar:
   - Replaces the native module with our Linux version
   - Updates keyboard key mappings
   - Preserves all other functionality
6. Creates a proper AppImage with:
   - Desktop entry for application menus
   - System-wide icon integration
   - Proper dependency management
   - Post-install configuration

# License

The build script in this repository is licensed under MIT License.

See [LICENSE-MIT](LICENSE-MIT) for details.

The Claude Desktop application, not included in this repository, is likely covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).
# claude-desktop-to-appimage
