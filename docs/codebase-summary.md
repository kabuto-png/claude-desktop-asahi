# Codebase Summary

## Overview
~5,200 LOC across 25+ shell scripts organized into 5 functional categories:
1. Build system (3 scripts)
2. Launcher & management (7 scripts)
3. Version management (6 scripts)
4. Persistence utilities (1 script)
5. Configuration (2 files)

## Build System Scripts

### scripts/builders/build-appimage.sh (206 LOC)
Universal entry point. Auto-detects OS and delegates to platform-specific builder.
- Detects Fedora Asahi ARM64 vs generic Linux
- Auto-detects download URL from Anthropic releases
- Validates dependencies (curl, appimagetool, etc.)
- Delegates to `fedora_asahi_build_script.sh` or `manual_appimage_builder.sh`
- Provides fallback builder selection
- Exit codes indicate success/failure

### scripts/builders/fedora_asahi_build_script.sh (441 LOC)
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

### scripts/builders/manual_appimage_builder.sh (169 LOC)
Fallback builder for manual/generic Linux systems without auto-detection.
- Manual version input
- Manual AppImage name input
- Basic dependency check
- Simpler patch application (subset of fedora_asahi script)
- No auto-update integration
- Used when auto-detect fails or user prefers manual control

## Launcher & Management Scripts

### scripts/launcher/claude-launcher.sh (502 LOC)
Main launcher (formerly claude-fixed-launcher-v2.sh). Run Claude Desktop AppImage with auto-update, HiDPI scaling, auth fixes, process management.

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

### scripts/tools/claude-auth-diagnostics.sh (265 LOC)
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

### scripts/tools/claude-kill.sh (102 LOC)
Clean process shutdown. Kill any running Claude Desktop instances.
- Finds processes by AppImage name/path
- Graceful termination with timeout
- Force kill if graceful fails
- Reports success/failure

### scripts/tools/claude-status.sh (92 LOC)
Status checker. Report running state, PID, resource usage.
- Check if Claude Desktop is running
- Display PID and launch time
- Show memory/CPU usage (if available)
- Check if auto-update is needed
- Display current version

### scripts/launcher/claude-launcher-no-update.sh (184 LOC)
Variant of main launcher without auto-update check. Useful for offline/restricted environments.
- Same HiDPI and process management
- Skip update check
- Direct AppImage execution

### scripts/launcher/claude-launcher-debug.sh (34 LOC)
Debug variant of launcher. Same as main launcher but with verbose output.
- Show all environment variables
- Display script execution trace (set -x)
- Useful for troubleshooting launch failures

## Version Management Scripts

### scripts/version/check-official-version.sh (148 LOC)
Check official Claude Desktop version from Anthropic.
- Query Anthropic RELEASES endpoint
- Cache result locally (~/.cache/claude-version-cache)
- Fallback to cached version if network unavailable
- Fallback to GitHub (aaddrick/claude-desktop-debian) releases
- Parse and return version string

### scripts/version/check-latest-version.sh (51 LOC)
Quick version check. Lighter weight than full check.
- Display current AppImage version
- Show latest official version
- Indicate if update available

### scripts/version/check-appimage-version.sh (42 LOC)
Inspect version embedded in AppImage file.
- Extract version from AppImage metadata
- Display build info
- No network calls

### scripts/version/get-actual-version.sh (66 LOC)
Extract version directly from app.asar inside AppImage.
- Mount AppImage
- Read version from asar metadata
- Return exact running version

### scripts/version/find-latest-claude.sh (26 LOC)
Find latest built AppImage file in current directory.
- Search for *.AppImage files
- Return newest by date

### scripts/version/investigate-version-sources.sh (69 LOC)
Debug script. Examine all version sources and compare.
- Check Anthropic official version
- Check GitHub fallback version
- Check local cached version
- Check AppImage version
- Display differences

## Persistence & Data Script

### scripts/tools/add-persistence-simple.sh (123 LOC)
Add data persistence to AppImage. Ensures config/cache survives across runs.
- Create overlay filesystem or bind mounts
- Preserve ~/.config/Claude
- Preserve ~/.local/share/Claude
- Preserve ~/.cache/Claude
- Create persistence directory structure

## Cleanup & Utility Scripts

### scripts/tools/cleanup-claude.sh (35 LOC)
Cleanup utility. Remove Claude Desktop files, caches, and temporary data.
- Remove AppImage file
- Clear config directory
- Clear cache directory
- Remove downloaded installers
- Prompt for confirmation

## Legacy Scripts

### scripts/legacy/ (Various)
Deprecated or experimental scripts maintained for reference.
- Old builder variants
- Experimental features
- Historical implementations

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

### CONTRIBUTING.md
Community contribution guidelines.
- Code style requirements
- Pull request process
- Issue reporting standards
- Development setup instructions

### GitHub Issue/PR Templates
Standardized templates in `.github/` for consistent issue/PR submissions.

## Architecture & Data Flow

### Build Time Flow
```
scripts/builders/build-appimage.sh
  ├─ Detect system
  ├─ Delegate to fedora_asahi_build_script.sh OR manual_appimage_builder.sh
  │  ├─ Download Windows installer (auto-detected URL)
  │  ├─ Extract app.asar
  │  ├─ Apply 4 patches
  │  ├─ Install claude-native stub
  │  └─ Create AppImage
  └─ Output: *.AppImage file
```

### Runtime Flow
```
scripts/launcher/claude-launcher.sh
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
  ├─ Run scripts/tools/claude-status.sh → Check if running
  ├─ Run scripts/tools/claude-auth-diagnostics.sh → Diagnose auth
  ├─ Run scripts/version/investigate-version-sources.sh → Check versions
  └─ Run scripts/launcher/claude-launcher-debug.sh → See detailed logs
```

## Code Quality & Infrastructure

### SPDX Headers
All shell scripts include Apache-2.0 SPDX license header at top of file.

### Linting & CI
- ShellCheck validation in GitHub Actions
- Automated test build on PR submissions
- Release workflow with checksums and artifacts

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
| Build (scripts/builders/) | 3 | 816 | 272 |
| Launcher (scripts/launcher/) | 3 | 720 | 240 |
| Tools (scripts/tools/) | 4 | 594 | 149 |
| Version (scripts/version/) | 6 | 402 | 67 |
| Config | 2 | 57 | 29 |
| Legacy & Experimental | 3+ | ~500 | ~150 |
| **TOTAL** | **21+** | **~3,089** | **~147** |

**Plus existing docs**: README (354), Complete Guide (397), Technical Docs (282), + 5 more = ~1,800 LOC

---

**Last Updated**: 2026-03-19
