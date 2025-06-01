# Project Structure

This document explains the organization of the Claude Desktop AppImage project.

## Root Directory

```
claude-desktop-to-appimage/
├── build-appimage.sh                 # Main build script (entry point)
├── README.md                         # Project documentation
├── LICENSE-MIT                       # License file
├── package.json                      # Node.js dependencies
├── .gitignore                        # Git ignore rules
├── claude_appimage_documentation.md  # Additional documentation
├── shfile/                           # Shell script utilities
└── [build scripts...]                # Platform-specific build scripts
```

## Build Scripts

### Main Entry Point
- **`build-appimage.sh`** - Universal build script that detects your system and calls the appropriate builder

### Platform-Specific Builders
- **`fedora_asahi_build_script.sh`** - Optimized for Fedora Asahi Remix (ARM64)
- **`manual_appimage_builder.sh`** - Manual AppImage builder for any architecture
- **`rebuild_and_fix.sh`** - Rebuilds and fixes existing AppImage

### Utility Scripts
- **`add_persistence_simple.sh`** - Adds data persistence to AppImage
- **`create_fedora_build_script.sh`** - Generates Fedora-specific build script
- **`create_manual_builder.sh`** - Generates manual builder script
- **`desktop_commander_install.sh`** - Installs Desktop Commander

## Shell Utilities (`shfile/`)

- **`claude_desktop_entry.sh`** - Creates desktop entry
- **`fix_data_persistence.sh`** - Fixes data persistence issues
- **`fix_data_persistence_v2.sh`** - Updated persistence fix
- **`fix_desktop_entry.sh`** - Fixes desktop integration
- **`manual_appimage_builder.sh`** - Manual builder utility
- **`user_install_claude.sh`** - User installation script

## Build Artifacts (Generated)

The following files are created during the build process and should not be committed:

- `Claude_Desktop-*.AppImage` - Built AppImage files
- `runtime-*` - AppImage runtime files
- `node_modules/` - npm dependencies
- `build/` - Build working directory
- `extracted/` - Extracted installer files
- `*.log` - Build logs

## Usage

1. **Quick Start**: `./build-appimage.sh`
2. **With Options**: `./build-appimage.sh --bundle-electron --appimagetool /path/to/tool`
3. **Help**: `./build-appimage.sh --help`

## Development

### Adding New Features
1. Create feature scripts in `shfile/` for reusable utilities
2. Update platform-specific builders as needed
3. Modify `build-appimage.sh` if new command-line options are needed

### Testing
- Test on different architectures (x86_64, aarch64)
- Test on different distributions (Ubuntu, Fedora, etc.)
- Verify AppImage works on target systems

### Contributing
1. Ensure all shell scripts are executable (`chmod +x *.sh`)
2. Update documentation for new features
3. Test build process thoroughly
4. Follow existing code style and conventions
