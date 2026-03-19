# Claude Desktop AppImage Builder

**Unofficial build system for running Claude Desktop on Linux as a self-contained AppImage, with optimized support for ARM64 (especially Fedora Asahi on Apple Silicon).**

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/Arch-aarch64%20%7C%20x86__64-blue)](#supported)
[![Distro](https://img.shields.io/badge/Distro-Fedora%20%7C%20Ubuntu%20%7C%20Debian-green)](#supported)

> **DISCLAIMER**: Unofficial project. Not affiliated with Anthropic. Report build issues here; Claude issues to Anthropic.

## Features

- 🚀 **Automated Build** - Single command builds complete AppImage
- 🖥️ **Linux Platform** - Enables Claude Desktop to run natively on Linux
- 💻 **Claude Code Support** - Works with local Claude Code instances
- 🔄 **Auto-Update** - Checks official releases with GitHub fallback
- 📱 **HiDPI Scaling** - Adaptive DPI detection and scaling
- 🔐 **Auth Diagnostics** - Token, config, and network troubleshooting
- 💾 **Data Persistence** - XDG-compliant config/cache storage

## Quick Start

```bash
# Clone repository
git clone https://github.com/your-repo/claude-desktop-to-appimage.git
cd claude-desktop-to-appimage

# Build AppImage (auto-detects system)
./build-appimage.sh

# Run it
./Claude_Desktop-*.AppImage
```

## System Requirements

### Supported
- **Fedora Asahi Remix** (ARM64 - Apple Silicon) - Optimized
- **Fedora 37+** (x86_64, aarch64)
- **Ubuntu 20.04+** (x86_64, aarch64)
- **Debian 11+** (x86_64, aarch64)
- Most Linux distros with required dependencies

### Dependencies
- `curl` - Download files
- `appimagetool` - Create AppImage
- `jq` - JSON parsing
- `unzip`/`7z` - Extract archives
- FUSE (usually pre-installed)
- Standard build tools (gcc, make)

Script checks and guides installation automatically.

## How It Works

```
1. Download official Windows installer from Anthropic
   ↓
2. Extract app.asar (Electron app archive)
   ↓
3. Apply 4 critical patches:
   • Window decorations (Linux-friendly titleBar)
   • Platform detection (Add Linux case for process.platform)
   • Origin validation (Remove isPackaged check for file://)
   • ClaudeVM stubs (Null IPC handlers)
   ↓
4. Replace Windows native modules with Linux stubs
   ↓
5. Repackage as Linux AppImage
   ↓
6. Launcher adds: Auto-update, HiDPI scaling, auth diagnostics
```

## Upstream References

**Patches from**: [christian-korneck/claude-desktop-asahi-fedora-arm64](https://github.com/christian-korneck/claude-desktop-asahi-fedora-arm64)
- Their project creates RPM packages; this one creates portable AppImages

**Original concept**: [aaddrick/claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian)
- Used as auto-update fallback source

## File Organization

```
├── build-appimage.sh                    # Universal builder (delegates to platform)
├── fedora_asahi_build_script.sh         # ARM64-optimized builder (primary)
├── manual_appimage_builder.sh           # Fallback builder
├── claude-fixed-launcher-v2.sh          # Main launcher (auto-update, HiDPI)
├── claude-auth-diagnostics.sh           # Auth troubleshooting
├── claude-kill.sh                       # Process cleanup
├── claude-status.sh                     # Status checker
├── check-official-version.sh            # Version detection
└── docs/                                # Complete documentation
    ├── project-overview-pdr.md          # Project goals & scope
    ├── codebase-summary.md              # File descriptions
    ├── code-standards.md                # Coding conventions
    ├── system-architecture.md           # Build/runtime design
    └── project-roadmap.md               # Status & future plans
```

## Usage

### Build
```bash
# Auto-detect and build
./build-appimage.sh

# With debug output
DEBUG=1 ./build-appimage.sh

# Manual build (if auto-detect fails)
./manual_appimage_builder.sh
```

### Launch
```bash
# Auto-update + HiDPI scaling (recommended)
./claude-fixed-launcher-v2.sh

# Without auto-update (offline mode)
./claude-fixed-launcher-v2.sh --no-update

# Run AppImage directly
./Claude_Desktop-*.AppImage
```

### Support Tools
```bash
# Check version and update status
./claude-status.sh

# Diagnose auth/token issues
./claude-auth-diagnostics.sh

# Kill running instances
./claude-kill.sh

# Cleanup and remove data
./cleanup-claude.sh
```

## Data Storage

Files persist in XDG directories:
- `~/.config/Claude/` - Config and login token
- `~/.local/share/Claude/` - Chat history and user data
- `~/.cache/Claude/` - Caches and temporary files

## Troubleshooting

### Build Fails
1. Check dependencies: `./build-appimage.sh` will list missing tools
2. Try Fedora-specific builder: `./fedora_asahi_build_script.sh`
3. Try manual builder: `./manual_appimage_builder.sh`
4. Enable debug: `DEBUG=1 ./fedora_asahi_build_script.sh`

### Launch Fails
1. Check status: `./claude-status.sh`
2. Diagnose auth: `./claude-auth-diagnostics.sh`
3. Make executable: `chmod +x Claude_Desktop-*.AppImage`
4. Check FUSE (Fedora): `ls /dev/fuse && sudo chmod 666 /dev/fuse`

### Token/Auth Issues
1. Run: `./claude-auth-diagnostics.sh` (comprehensive check)
2. Verify: `~/.config/Claude/access_token.txt` exists
3. Check permissions: `chmod 600 ~/.config/Claude/access_token.txt`
4. Login again if needed via Claude Desktop UI

### HiDPI Not Working
1. Auto-detection runs automatically
2. Manual override: `QT_SCALE_FACTOR=2 ./Claude_Desktop-*.AppImage`
3. Wayland users: May need `GDK_SCALE=2` instead

### More Help
- See `docs/` directory for detailed documentation
- GitHub Issues for bug reports with reproducible steps
- Discussions for questions and feature ideas

## Architecture

### Build-Time (one-time)
- Enter `build-appimage.sh` → System detection → Platform-specific builder
- Download Windows installer → Extract app.asar
- Apply 4 patches + native stubs → Create AppImage

### Runtime
- Launcher checks for updates (Anthropic RELEASES + GitHub fallback)
- Applies HiDPI scaling based on display metrics
- Sets environment variables (XDG dirs, SSL certs, etc.)
- Launches AppImage with Electron
- Cleans up processes on exit

### Update Mechanism
1. Check Anthropic official RELEASES endpoint
2. Fall back to GitHub (aaddrick) if unavailable
3. Cache locally (~/.cache/claude-version-cache) for offline use
4. Download and atomic swap if new version found

## Project Status

✅ **Stable** - Core functionality complete and tested
- Build works on Fedora Asahi ARM64
- AppImage runs Claude Desktop
- Claude Code integration working
- Auto-update functional
- HiDPI scaling adaptive
- Auth diagnostics comprehensive

🔄 **In Progress** - Documentation and code review (Phase 2)

🔲 **Planned** - x86_64 generic support, additional distros, package alternatives

See `docs/project-roadmap.md` for detailed timeline and known issues.

## Known Limitations

1. **ARM64 native modules** - Not available on Linux; stubbed with no-ops (works fine)
2. **Window management** - Some decorations may differ slightly from Windows
3. **Manual installation** - Not in official package repos (unofficial project)
4. **Requires restart** - Updates apply on next launch

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and PR guidelines.

Contributions welcome:
- Bug reports: GitHub Issues
- Code: Pull requests (include tests if possible)
- Docs: Improvements and clarifications
- Testing: Report on different distros/architectures

## License & Credits

**Build Scripts**: Apache License 2.0 (see [LICENSE](LICENSE))
**Claude Desktop**: Anthropic's application, downloaded from official servers

**Credit**:
- [christian-korneck](https://github.com/christian-korneck) - 4 critical patches
- [aaddrick](https://github.com/aaddrick/claude-desktop-debian) - Original AppImage concept
- Anthropic, Asahi Linux, Fedora community

## More Info

- **Overview & Goals**: `docs/project-overview-pdr.md`
- **Codebase Guide**: `docs/codebase-summary.md`
- **Architecture Details**: `docs/system-architecture.md`
- **Roadmap & Status**: `docs/project-roadmap.md`
- **Code Standards**: `docs/code-standards.md`

---

**Questions?** Check docs or open an issue on GitHub.
**Found helpful?** Star this repo and share!
