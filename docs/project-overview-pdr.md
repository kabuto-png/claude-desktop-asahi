# Project Overview & Product Requirements

## Project Name
**Claude Desktop AppImage Builder** - Unofficial build system for running Claude Desktop on Linux as a self-contained AppImage.

## Vision
Enable Claude Desktop to run natively on Linux systems (ARM64/aarch64 and x86_64), particularly Fedora Asahi on Apple Silicon, by extracting and patching the official Windows installer.

## Problem Statement
Claude Desktop is distributed as a Windows/macOS application. Linux users, especially on ARM64 architecture (Apple Silicon), have no official way to run Claude Desktop. This project bridges that gap.

## Solution
1. Download official Claude Desktop Windows installer from Anthropic
2. Extract Electron app archive (app.asar)
3. Apply 4 critical patches to enable Linux support
4. Replace Windows-specific native modules with Linux-compatible stubs
5. Repackage as Linux AppImage
6. Provide intelligent launcher with auto-update, HiDPI scaling, auth diagnostics

## Scope

### In Scope
- Automated AppImage build from official Windows installer
- 4 critical patches (platform detection, window decorations, origin validation, ClaudeVM stubs)
- Auto-update capability with fallback sources
- HiDPI/scaling support for high-resolution displays
- Authentication diagnostics and troubleshooting
- Process management and cleanup utilities
- Version detection and status checking
- Support for Fedora Asahi ARM64 and generic Linux

### Out of Scope
- Building from source (uses official binaries)
- Creating native packages (RPM, DEB) - AppImage chosen for portability
- Maintaining parity with macOS-specific features
- Supporting older Electron versions

## Key Features

1. **Automated Build** - Single command builds complete AppImage
2. **Linux Platform Support** - Patches enable Electron to recognize Linux
3. **Claude Code Integration** - Works with local Claude Code instances
4. **Auto-Update** - Checks Anthropic RELEASES endpoint, falls back to GitHub
5. **HiDPI Scaling** - Adaptive scaling for high-DPI displays
6. **Auth Diagnostics** - Comprehensive token, config, and network checking
7. **Process Management** - Cleanup, status checking, debug utilities
8. **Data Persistence** - XDG-compliant config/cache storage

## Upstream References & Attribution

### Direct Dependencies
- **christian-korneck/claude-desktop-asahi-fedora-arm64** (GitHub) - Source of 4 critical patches
  - Platform detection (`if(process.platform==="linux")`)
  - Window decorations (`titleBarStyle:"default"`)
  - Origin validation (remove `isPackaged` check)
  - ClaudeVM stubs (null-returning IPC handlers)
  - Their approach: RPM packaging; This project: AppImage format

- **aaddrick/claude-desktop-debian** (GitHub) - Original AppImage concept
  - Auto-update design with GitHub releases fallback
  - Data persistence approach
  - Process management patterns

- **bsneed/claude-desktop-fedora** - Indirect ancestor (credited by christian-korneck)

### Relationship to Upstream
- **Not a fork** - Independent build system using same patch concepts
- **Complementary** - Their RPM approach; our AppImage approach (portable across distros)
- **Fallback integration** - Uses aaddrick's GitHub releases as auto-update fallback
- **Improvements** - HiDPI scaling, enhanced diagnostics, Fedora Asahi optimization

## Technical Constraints

1. **Electron/Asar Format** - Must work with Electron's asar archive structure
2. **Native Module Compatibility** - Windows modules must be stubbed for Linux
3. **Platform Detection** - Electron patches must be minimal and non-invasive
4. **Update Sources** - Must handle both Anthropic official and GitHub fallback
5. **XDG Compliance** - Must respect Linux data directory standards
6. **ARM64 Support** - All dependencies must support aarch64 architecture

## Success Criteria

1. ✓ AppImage builds without errors on Fedora Asahi ARM64
2. ✓ Launched AppImage runs Claude Desktop
3. ✓ Claude Code integration works (can request local code help)
4. ✓ Auto-update detects newer versions
5. ✓ HiDPI scaling works on high-resolution displays
6. ✓ Auth diagnostics help troubleshoot token issues
7. ✓ Data persists across launches
8. ✓ Handles graceful shutdown and cleanup

## File Organization

```
/
├── docs/                           # Documentation (this directory)
│   ├── project-overview-pdr.md    # This file
│   ├── codebase-summary.md        # File inventory & descriptions
│   ├── code-standards.md          # Shell scripting conventions
│   ├── system-architecture.md     # Build/runtime flow diagrams
│   └── project-roadmap.md         # Status, issues, roadmap
├── build-appimage.sh              # Universal entry point
├── fedora_asahi_build_script.sh   # Primary builder (Fedora ARM64)
├── manual_appimage_builder.sh     # Fallback builder
├── claude-fixed-launcher-v2.sh    # Main launcher
├── claude-auth-diagnostics.sh     # Auth troubleshooting
├── claude-kill.sh                 # Process cleanup
├── claude-status.sh               # Status checker
└── ... (other utilities, ~19 total shell scripts + config)
```

## Non-Functional Requirements

1. **Performance** - Build should complete in < 5 minutes on ARM64
2. **Compatibility** - Work on Fedora 37+ with Wayland/X11
3. **Reliability** - Auto-update should not break running instances
4. **Maintainability** - Scripts should be self-documenting and modular
5. **Security** - Should not expose tokens or credentials in logs
6. **User Experience** - Clear error messages and recovery options

## Known Limitations

1. Native modules (node-gyp dependencies) not fully compatible with ARM64 - stubbed with no-ops
2. Some window management features may not work identically to Windows
3. Requires manual AppImage creation (not packaged by Anthropic)
4. Updates require application restart

## Future Improvements

1. Add deb/rpm packaging for easier installation
2. Support other architectures (x86_64 focus first)
3. Integrated update notifier UI
4. Clipboard sync with system
5. Audio/video codec support improvements
6. Container/Nix packaging alternatives

## Version Tracking

- **Claude Desktop**: Follows official version (currently 0.14+)
- **AppImage Builder**: Maintains own versioning based on build date/iteration
- **Patches**: Stable (based on upstream claude-desktop-asahi-fedora-arm64)

---

**Last Updated**: 2026-03-19
**Status**: Active Development
**Primary Maintainer**: Community
