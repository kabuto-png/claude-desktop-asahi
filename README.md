# Claude Desktop AppImage Builder

Build and run [Claude Desktop](https://claude.ai/download) on Linux as a portable AppImage. Optimized for ARM64 (Fedora Asahi on Apple Silicon) with x86_64 support.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/Arch-aarch64%20%7C%20x86__64-blue)](#system-requirements)
[![ShellCheck](https://github.com/kabuto-png/claude-desktop-to-appimage/actions/workflows/lint.yml/badge.svg)](https://github.com/kabuto-png/claude-desktop-to-appimage/actions/workflows/lint.yml)

> **Disclaimer**: Unofficial project. Not affiliated with Anthropic. Report build issues here; report Claude issues to Anthropic.

## Quick Start

```bash
git clone https://github.com/kabuto-png/claude-desktop-to-appimage.git
cd claude-desktop-to-appimage

# Build (auto-detects architecture and latest version)
./build-appimage.sh

# Run
./Claude_Desktop-*-aarch64.AppImage

# Optional: add data persistence
./add_persistence_simple.sh
./Claude_Desktop-*-aarch64-persistent.AppImage
```

## How It Works

```
Download Windows installer from Anthropic
  → Extract app.asar (Electron app archive)
  → Apply 4 patches (window decorations, platform detection,
    origin validation, ClaudeVM stubs)
  → Replace Windows native modules with Linux stubs
  → Package as AppImage
```

The build scripts auto-detect the latest Claude Desktop version from Anthropic's RELEASES endpoint. You can override with `--claude-download-url <url>`.

## System Requirements

**Architectures**: x86_64, aarch64 (Apple Silicon, Raspberry Pi 4+)

**Distributions**: Fedora 35+, Ubuntu 20.04+, Debian 11+, Arch, and most Linux distros

**Dependencies**: `curl`, `jq`, `7z` or `unzip`, `appimagetool`, Node.js, npm, FUSE

The build script checks for missing dependencies and provides installation commands.

## Usage

### Build Options

```bash
./build-appimage.sh                              # Auto-detect everything
./build-appimage.sh --claude-download-url <url>   # Custom installer URL
./build-appimage.sh --bundle-electron             # Bundle Electron runtime
./fedora_asahi_build_script.sh                    # Fedora Asahi ARM64 specific
./manual_appimage_builder.sh                      # Manual fallback
```

### Launcher

```bash
./claude-fixed-launcher-v2.sh            # Recommended: auto-update + HiDPI
./claude-fixed-launcher-v2.sh --scale 2  # Force 2x HiDPI scaling
./claude-fixed-launcher-v2.sh --diagnose # Auth diagnostics
```

### Tools

```bash
./claude-status.sh              # Check running state and version
./claude-auth-diagnostics.sh    # Diagnose auth/token issues
./claude-kill.sh                # Kill running instances
./cleanup-claude.sh             # Remove all Claude data
./check-official-version.sh     # Check latest version available
```

## Data Storage

All data persists in XDG-compliant directories:

| Directory | Contents |
|-----------|----------|
| `~/.config/Claude/` | Config, login token, MCP config |
| `~/.local/share/Claude/` | Conversations, user data |
| `~/.cache/Claude/` | Caches, temporary files |

## Troubleshooting

**Build fails** — Check dependencies (`./build-appimage.sh` lists missing tools), try `./fedora_asahi_build_script.sh` for ARM64, or `./manual_appimage_builder.sh` as fallback.

**AppImage won't start** — Run `chmod +x Claude_Desktop-*.AppImage`. Check FUSE: `ls /dev/fuse && sudo chmod 666 /dev/fuse`.

**Auth issues** — Run `./claude-auth-diagnostics.sh` for a comprehensive check. Verify `~/.config/Claude/` permissions.

**HiDPI scaling** — Auto-detected on Apple Silicon. Override: `./claude-fixed-launcher-v2.sh --scale 2` or set `GDK_SCALE=2`.

See `docs/` for detailed documentation.

## Project Structure

```
build-appimage.sh               # Universal builder (auto-detects platform)
fedora_asahi_build_script.sh    # ARM64-optimized builder
manual_appimage_builder.sh      # Fallback builder
claude-fixed-launcher-v2.sh     # Main launcher (auto-update, HiDPI)
claude-auth-diagnostics.sh      # Auth troubleshooting
check-official-version.sh       # Version detection (official + GitHub)
claude-kill.sh / claude-status.sh / cleanup-claude.sh  # Management tools
add_persistence_simple.sh       # Data persistence setup
docs/                           # Architecture, code standards, roadmap
```

## Credits

- [christian-korneck](https://github.com/christian-korneck/claude-desktop-asahi-fedora-arm64) — 4 critical patches for Linux compatibility
- [aaddrick](https://github.com/aaddrick/claude-desktop-debian) — Original concept and auto-update fallback source
- Anthropic, Asahi Linux, Fedora community

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Claude Desktop itself is Anthropic's application, downloaded from their official servers.
