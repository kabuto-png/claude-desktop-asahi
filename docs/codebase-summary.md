# Codebase Summary

## Overview
~5,200 LOC across 25+ shell scripts organized into 5 functional categories:
1. Build system (3 scripts)
2. Launcher & management (7 scripts)
3. Version management (6 scripts)
4. Persistence utilities (1 script)
5. Configuration (2 files)

## Build System Scripts

### build-appimage.sh (206 LOC)
Universal entry point. Auto-detects OS and delegates to platform-specific builder.
- Detects Fedora Asahi ARM64 vs generic Linux
- Validates dependencies (curl, appimagetool, etc.)
- Delegates to `fedora_asahi_build_script.sh` or `manual_appimage_builder.sh`
- Provides fallback builder selection
- Exit codes indicate success/failure

### fedora_asahi_build_script.sh (441 LOC)
Primary builder for Fedora Asahi ARM64 (Fedora 37+). Implements complete build pipeline with 4 critical patches.
**Key steps:**
1. Validate Fedora version and architecture
2. Install/update dependencies (curl, aria2, appimagetool, etc.)
3. Check official Claude Desktop version
4. Download Windows installer (WinRAR archive)
5. Extract app.asar from installer
6. Apply 4 critical patches:
   - Window decorations: `titleBarStyle:"hidden"` → `titleBarStyle:"default"`
   - Platform detection: Add Linux case to `process.platform` checks
   - Origin validation: Remove `isPackaged` check for file:// protocol
   - ClaudeVM stubs: Add null-returning IPC handlers
7. Install claude-native stub module (replaces Windows native bindings)
8. Use appimagetool to create AppImage
9. Set executable permissions
10. Display build success with file location

**Key functions:**
- `validate_system()` - Check Fedora + ARM64
- `install_dependencies()` - Install dnf packages
- `download_and_extract()` - Get installer, extract asar
- `apply_patches()` - Core patch application
- `build_appimage()` - Create final AppImage

### manual_appimage_builder.sh (169 LOC)
Fallback builder for manual/generic Linux systems without auto-detection.
- Manual version input
- Manual AppImage name input
- Basic dependency check
- Simpler patch application (subset of fedora_asahi script)
- No auto-update integration
- Used when auto-detect fails or user prefers manual control

## Launcher & Management Scripts

### claude-fixed-launcher-v2.sh (502 LOC)
Main launcher. Run Claude Desktop AppImage with auto-update, HiDPI scaling, auth fixes, process management.

**Features:**
- Kill existing processes
- Check/apply HiDPI scaling (adaptive to display)
- Auto-update: Check Anthropic RELEASES endpoint + GitHub fallback
- Download updated AppImage if newer version available
- Parse CLI args (--no-update, --debug, etc.)
- Launch AppImage with environment variables
- Monitor for crashes
- Provide friendly error messages

**Key functions:**
- `setup_directories()` - Create XDG dirs
- `get_latest_version()` - Check official + fallback sources
- `setup_hidpi_scaling()` - Adaptive DPI detection
- `launch_appimage()` - Execute with proper env setup

### claude-auth-diagnostics.sh (265 LOC)
Comprehensive auth troubleshooting. Checks config, permissions, tokens, network.

**Diagnostic checks:**
- Config file existence/permissions (~/.config/Claude)
- Token file validity and permissions (~/.config/Claude/access_token.txt)
- Network connectivity to Anthropic API
- Environment variable setup (ANTHROPIC_API_KEY, etc.)
- SSL certificate validation
- Proxy configuration
- DNS resolution
- Cookie/cache integrity

**Output:** Detailed report with issues and remediation steps.

### claude-kill.sh (102 LOC)
Clean process shutdown. Kill any running Claude Desktop instances.
- Finds processes by AppImage name/path
- Graceful termination with timeout
- Force kill if graceful fails
- Reports success/failure

### claude-status.sh (92 LOC)
Status checker. Report running state, PID, resource usage.
- Check if Claude Desktop is running
- Display PID and launch time
- Show memory/CPU usage (if available)
- Check if auto-update is needed
- Display current version

### claude-launcher-no-update.sh (184 LOC)
Variant of main launcher without auto-update check. Useful for offline/restricted environments.
- Same HiDPI and process management
- Skip update check
- Direct AppImage execution

### debug-claude-launcher.sh (34 LOC)
Debug variant of launcher. Same as main launcher but with verbose output.
- Show all environment variables
- Display script execution trace (set -x)
- Useful for troubleshooting launch failures

## Version Management Scripts

### check-official-version.sh (148 LOC)
Check official Claude Desktop version from Anthropic.
- Query Anthropic RELEASES endpoint
- Cache result locally (~/.cache/claude-version-cache)
- Fallback to cached version if network unavailable
- Fallback to GitHub (aaddrick/claude-desktop-debian) releases
- Parse and return version string

### check_latest_version.sh (51 LOC)
Quick version check. Lighter weight than full check.
- Display current AppImage version
- Show latest official version
- Indicate if update available

### check_appimage_version.sh (42 LOC)
Inspect version embedded in AppImage file.
- Extract version from AppImage metadata
- Display build info
- No network calls

### get_actual_version.sh (66 LOC)
Extract version directly from app.asar inside AppImage.
- Mount AppImage
- Read version from asar metadata
- Return exact running version

### find_latest_claude.sh (26 LOC)
Find latest built AppImage file in current directory.
- Search for *.AppImage files
- Return newest by date

### investigate_version_sources.sh (69 LOC)
Debug script. Examine all version sources and compare.
- Check Anthropic official version
- Check GitHub fallback version
- Check local cached version
- Check AppImage version
- Display differences

## Persistence & Data Script

### add_persistence_simple.sh (123 LOC)
Add data persistence to AppImage. Ensures config/cache survives across runs.
- Create overlay filesystem or bind mounts
- Preserve ~/.config/Claude
- Preserve ~/.local/share/Claude
- Preserve ~/.cache/Claude
- Create persistence directory structure

## Configuration Files

### package.json (8 LOC)
npm configuration for development. Lists Electron as devDependency for local debugging if needed.

### .gitignore (49 LOC)
Git ignore rules. Excludes:
- Build artifacts (*.AppImage, *.tar.*)
- Node modules
- Cache files
- Downloaded installers
- Temporary build files

## Cleanup & Utility Scripts

### cleanup-claude.sh (35 LOC)
Cleanup utility. Remove Claude Desktop files, caches, and temporary data.
- Remove AppImage file
- Clear config directory
- Clear cache directory
- Remove downloaded installers
- Prompt for confirmation

## Architecture & Data Flow

### Build Time Flow
```
build-appimage.sh
  ├─ Detect system
  ├─ Delegate to fedora_asahi_build_script.sh OR manual_appimage_builder.sh
  │  ├─ Download Windows installer
  │  ├─ Extract app.asar
  │  ├─ Apply 4 patches
  │  ├─ Install claude-native stub
  │  └─ Create AppImage
  └─ Output: *.AppImage file
```

### Runtime Flow
```
claude-fixed-launcher-v2.sh
  ├─ Kill existing instances (claude-kill.sh logic)
  ├─ Setup XDG directories
  ├─ Check for updates
  │  ├─ Query Anthropic RELEASES
  │  └─ Fallback to GitHub releases
  ├─ Download if update available
  ├─ Setup HiDPI scaling
  ├─ Set environment variables
  └─ Launch AppImage with Electron
```

### Support/Troubleshooting Flow
```
User encounters issue
  ├─ Run claude-status.sh → Check if running
  ├─ Run claude-auth-diagnostics.sh → Diagnose auth
  ├─ Run investigate_version_sources.sh → Check versions
  └─ Run debug-claude-launcher.sh → See detailed logs
```

## Code Patterns & Conventions

### Error Handling
- Use `set -e` for exit on error
- Trap EXIT for cleanup
- Explicit error messages with remediation
- Exit codes: 0 (success), 1 (general error), 2 (build error), 3 (missing deps)

### Variable Naming
- `UPPER_CASE` for constants (APPIMAGE_NAME, CLAUDE_VERSION)
- `lower_case` for variables (version, status, count)
- Prefixes for clarity: `is_` (boolean), `get_` (retrieve), `check_` (validate)

### Function Organization
- Header comment with purpose and exit codes
- Logical grouping (validation, download, build, execute)
- Single responsibility principle
- Early return pattern for error checking

### Paths & Directories
- Use XDG Base Directory spec:
  - Config: ~/.config/Claude
  - Data: ~/.local/share/Claude
  - Cache: ~/.cache/Claude
- Absolute paths in critical operations
- Variable for AppImage location (defaults to ./claude.AppImage or system-installed)

### Dependencies
- All major tools documented
- Fallback mechanisms when possible (e.g., curl vs aria2 for downloads)
- Version checks for Fedora/Electron compatibility

## Statistics

| Category | Files | LOC | Avg LOC/file |
|----------|-------|-----|--------------|
| Build | 3 | 816 | 272 |
| Launcher | 7 | 1,111 | 159 |
| Version Mgmt | 6 | 402 | 67 |
| Persistence | 1 | 123 | 123 |
| Config | 2 | 57 | 29 |
| Cleanup | 1 | 35 | 35 |
| **TOTAL** | **20** | **2,544** | **127** |

**Plus existing docs**: README (354), Complete Guide (397), Technical Docs (282), + 5 more = ~1,800 LOC

---

**Last Updated**: 2026-03-19
