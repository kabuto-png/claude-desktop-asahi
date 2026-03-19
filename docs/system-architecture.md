# System Architecture

## High-Level Overview

Claude Desktop AppImage Builder is a 3-phase system:
1. **Build Phase** - Extract and patch official Windows installer → AppImage
2. **Runtime Phase** - Launch AppImage with setup and updates
3. **Support Phase** - Diagnostics, version checks, process management

## Build Architecture

### Build Flow (Sequential)

```
User runs: ./scripts/builders/build-appimage.sh
           |
           v
    Auto-detect OS
    (Fedora ARM64? Generic Linux? macOS?)
           |
           +---> Fedora Asahi ARM64
           |     └─ scripts/builders/fedora_asahi_build_script.sh
           |
           +---> Generic Linux
           |     └─ scripts/builders/manual_appimage_builder.sh
           |
           +---> Unsupported
                 └─ Error + Exit
```

### Fedora Asahi Build Pipeline (Detailed)

```
1. System Validation
   ├─ Check OS is Fedora 37+
   ├─ Check architecture is aarch64
   └─ Exit if requirements not met

2. Dependency Installation
   ├─ Install: curl, aria2, appimagetool, xdg-utils, jq
   └─ Verify each tool is available

3. Version Detection
   ├─ Query Anthropic RELEASES endpoint
   ├─ Parse version number
   └─ Display to user

4. Download Windows Installer
   ├─ Auto-detect download URL from RELEASES data
   ├─ Download WinRAR archive from Anthropic
   ├─ Verify checksum (if available)
   └─ Extract to temporary directory

5. Extract app.asar
   ├─ Locate app.asar inside installer
   ├─ Extract with unzip/7z
   └─ Decompress asar archive

6. Apply 4 Critical Patches
   ├─ Patch 1: Window Decorations
   │  └─ Replace titleBarStyle:"hidden" → titleBarStyle:"default"
   │
   ├─ Patch 2: Platform Detection
   │  └─ Add if(process.platform==="linux") case
   │
   ├─ Patch 3: Origin Validation
   │  └─ Remove isPackaged check for file:// protocol
   │
   └─ Patch 4: ClaudeVM Stubs
      └─ Add IPC channel handlers returning null

7. Install Native Module Stubs
   ├─ Create claude-native module directory
   └─ Add index.js with Linux-compatible stubs
      └─ KeyboardKey enum, window management no-ops

8. Repackage Electron App
   ├─ Use appimagetool to create AppImage
   ├─ Include patched app.asar
   ├─ Include dependencies
   └─ Generate executable binary

9. Finalize
   ├─ Set executable permissions (chmod +x)
   ├─ Verify AppImage is valid
   └─ Display success + location
```

### Patch Details

#### Patch 1: Window Decorations (titleBarStyle)
**Why**: Electron on Linux with `titleBarStyle:"hidden"` causes rendering issues without proper WM support.

**Change**: In Electron main process, change:
```javascript
// Before (Windows/macOS style)
titleBarStyle: 'hidden'

// After (Linux style)
titleBarStyle: 'default'
```

**File**: Typically in main Electron file within app.asar

#### Patch 2: Platform Detection
**Why**: Claude checks `process.platform` to determine OS. Windows installer has no Linux case.

**Change**: Add Linux handling:
```javascript
// Before
if (process.platform === 'win32') {
    // Windows specific
} else if (process.platform === 'darwin') {
    // macOS specific
}

// After
if (process.platform === 'win32') {
    // Windows specific
} else if (process.platform === 'darwin') {
    // macOS specific
} else if (process.platform === 'linux') {
    // Linux specific (mostly same as macOS)
}
```

**Impact**: Enables Claude Code, file dialogs, native UI features on Linux

#### Patch 3: Origin Validation (isPackaged removal)
**Why**: Claude checks `app.isPackaged` for origin validation. AppImage file:// protocol fails this check.

**Change**: Remove or modify check:
```javascript
// Before
if (!app.isPackaged || !isOriginValid(origin)) {
    reject(new Error('Invalid origin'));
}

// After
if (!isOriginValid(origin)) {  // or make isPackaged always true
    reject(new Error('Invalid origin'));
}
```

**Impact**: Allows AppImage to run without origin permission errors

#### Patch 4: ClaudeVM Stubs
**Why**: Claude may check for ClaudeVM IPC channel. Windows installer has handlers; Linux doesn't.

**Change**: Add null-returning handlers:
```javascript
ipcMain.handle('claude-vm:check', () => null);
ipcMain.handle('claude-vm:status', () => ({ available: false }));
// ... other stub handlers
```

**Impact**: Prevents crashes from missing IPC handlers

### Native Module Strategy

**Problem**: Windows-compiled native modules (node-gyp) won't run on Linux ARM64.

**Solution**: Create `claude-native` stub module:
```javascript
// Stub provides same API but returns no-ops
module.exports = {
    KeyboardKey: { /* enum */ },
    getKeyboardState: () => ({}),
    setWindowState: () => {},
    monitorSystemSettings: () => {}
    // ... other stubbed methods
};
```

**Location**: Inserted into app.asar at `node_modules/claude-native/index.js`

## Runtime Architecture

### Launcher Flow (claude-launcher.sh)

```
User runs: ./scripts/launcher/claude-launcher.sh [--no-update] [--debug]
           |
           v
1. Setup Phase
   ├─ Parse CLI arguments
   ├─ Create XDG directories (~/.config/Claude, etc.)
   └─ Kill any existing Claude processes

2. HiDPI Setup Phase
   ├─ Detect display DPI
   ├─ Calculate scale factor
   └─ Set QT_SCALE_FACTOR or GDK_SCALE

3. Update Check Phase (unless --no-update)
   ├─ Get latest version
   │  ├─ Check Anthropic RELEASES endpoint
   │  ├─ Parse version number
   │  └─ Fallback to GitHub (aaddrick/claude-desktop-debian)
   │
   ├─ Compare with local AppImage version
   │
   ├─ If update available
   │  ├─ Download new AppImage
   │  ├─ Verify checksum
   │  ├─ Replace old AppImage
   │  └─ Report update to user
   │
   └─ If no update
       └─ Continue with current AppImage

4. Environment Setup Phase
   ├─ Set DISPLAY variable (for X11)
   ├─ Set QT_QPA_PLATFORM if Wayland
   ├─ Configure SSL certificate path
   ├─ Set ANTHROPIC_API_KEY if available
   └─ Set other runtime variables

5. Launch Phase
   ├─ Execute AppImage
   ├─ Monitor process
   └─ Report exit code

6. Cleanup Phase
   ├─ Remove lock files
   ├─ Flush logs
   └─ Clean temporary files
```

### Update Mechanism

#### Version Sources (Priority Order)
1. **Local Cache** (~/.cache/claude-version-cache)
   - TTL: 24 hours
   - Fallback if network unavailable

2. **Anthropic Official** (https://api.anthropic.com/releases)
   - API endpoint listing official versions
   - Most authoritative source
   - May require authentication

3. **GitHub Fallback** (aaddrick/claude-desktop-debian releases)
   - Community-maintained mirror
   - Used if Anthropic endpoint fails
   - Provides pre-built AppImages

#### Update Decision Tree
```
Current version: v0.14.10
Latest available: v0.14.11

Is new version > current?
  YES → Download AppImage
        Verify integrity
        Replace old file
        Restart application

  NO  → Continue with current version
```

#### Download Strategy
1. Use `aria2` if available (parallel downloads, faster)
2. Fall back to `curl` if aria2 missing
3. Verify via checksum if provided
4. Atomic replacement (download to temp, then move)

## Data Storage Architecture

### XDG Base Directory Compliance

```
~/.config/Claude/
├─ access_token.txt          # API token (chmod 600)
├─ settings.json             # User preferences
├─ window-state.json         # Last window position/size
└─ app-update.json           # Update metadata

~/.local/share/Claude/
├─ history.db               # Chat history (SQLite)
├─ cache/                   # Binary caches
└─ plugins/                 # Plugin directory

~/.cache/Claude/
├─ claude-version-cache     # Cached version info
├─ network-cache/           # HTTP cache
└─ temporary-files/         # Temp storage
```

### Persistence Strategy

#### Simple Approach (add_persistence_simple.sh)
- Bind mount user's ~/.config/Claude → AppImage mount point
- Persist ~/.local/share/Claude → user's home
- Persist ~/.cache/Claude → user's cache

#### Advanced Approach (Optional Future)
- OverlayFS for copy-on-write modifications
- Allows multiple AppImage instances
- Automatic cleanup of temporary changes

## Authentication & Token Management

### Token Storage

```
~/.config/Claude/access_token.txt
├─ Permissions: 600 (user read/write only)
├─ Format: Plain text token
└─ Set by Claude Desktop on first login
```

### Token Validation Flow

```
User launches Claude
     |
     v
Check ~/.config/Claude/access_token.txt
     |
     +---> Token exists?
     |     ├─ YES → Validate format
     |     │        ├─ Valid → Continue launch
     |     │        └─ Invalid → Prompt re-auth
     |     │
     |     └─ NO → Prompt user to login
     |
     v
Show Claude login UI (if needed)
User enters credentials
Token saved locally
```

### Diagnostics (claude-auth-diagnostics.sh)

```
Check 1: File Existence
  ~/.config/Claude/access_token.txt exists?

Check 2: Permissions
  Is file readable by user? (644+)
  Is file not world-readable? (should be 600)

Check 3: Token Format
  Does token match expected format?
  (Usually: uuid or base64 string)

Check 4: Network Connectivity
  Can reach Anthropic API?
  Check DNS resolution
  Check SSL certificates

Check 5: API Validation
  Send test request with token
  Does API accept it?

Check 6: Environment
  Is ANTHROPIC_API_KEY set?
  Does it match token file?

Check 7: Proxy Configuration
  Any HTTP_PROXY / HTTPS_PROXY set?
  Does proxy interfere?

Check 8: SSL Certificates
  Are system SSL certs present?
  Can curl find CA bundle?
```

## Process Management

### Process Lifecycle

```
Start
  |
  v
scripts/launcher/claude-launcher.sh
  ├─ Kill old Claude processes
  └─ Launch AppImage
      |
      v
    Electron Main Process
      ├─ Render processes (tabs)
      ├─ IPC channels
      └─ Native modules (stubs)
      |
      v
    User Interaction
      ├─ Chat
      ├─ Code submission
      └─ Settings
      |
      v
    User Closes Window
      or
    SIGTERM received
      |
      v
    Graceful Shutdown
      ├─ Save state
      ├─ Close IPC
      └─ Exit(0)
      |
      v
Launcher Cleanup
  ├─ Remove lock files
  ├─ Flush logs
  └─ Report exit code
```

### Process Cleanup (scripts/tools/claude-kill.sh)

```
Find processes
  |
  v
Match by:
  ├─ Process name (claude, AppImage)
  ├─ Process path (containing "claude.AppImage")
  └─ Parent process (launcher script)
  |
  v
Graceful Termination
  ├─ Send SIGTERM
  ├─ Wait 5 seconds
  └─ Check if exited?
      ├─ YES → Done
      └─ NO → Continue to force kill
  |
  v
Force Kill (if needed)
  └─ Send SIGKILL
```

## HiDPI Scaling Architecture

### Problem
- Electron on Linux may not auto-detect high-DPI displays
- AppImage may run at 96 DPI instead of native resolution
- Results in blurry text and UI elements

### Solution
Auto-detect and apply scaling:

```
Detect display
  |
  v
Query screen metrics (xdotool, xrandr)
  ├─ Physical resolution (pixels)
  ├─ Physical size (mm)
  └─ Calculate DPI
  |
  v
Calculate scale factor
  ├─ If DPI < 100: scale = 1.0
  ├─ If DPI 100-150: scale = 1.25 or 1.5
  ├─ If DPI 150-200: scale = 2.0
  └─ If DPI > 200: scale = 2.5+
  |
  v
Apply to Electron
  ├─ QT_SCALE_FACTOR (for Qt apps)
  ├─ GDK_SCALE (for GTK apps)
  └─ ELECTRON_OZONE_PLATFORM (Wayland specific)
```

## Module Dependencies

### Required External Tools
- `curl` - HTTP downloads
- `aria2` - Parallel downloads (fallback: curl)
- `appimagetool` - Create AppImage
- `jq` - JSON parsing
- `xdg-utils` - XDG directory handling
- `unzip` / `7z` - Archive extraction

### Optional Tools
- `aria2` - Faster downloads (fallback to curl)
- `xdotool` - HiDPI detection (fallback: static scale)
- `jq` - Version parsing (fallback: grep)

### Bundled in AppImage
- Electron runtime
- Node.js runtime
- Claude Desktop application

## Error Handling Architecture

### Error Categories

```
Build Errors (exit code 2)
  ├─ Failed to download installer
  ├─ Failed to extract asar
  ├─ Failed to apply patches
  └─ Failed to create AppImage

Dependency Errors (exit code 3)
  ├─ Missing appimagetool
  ├─ Missing curl
  └─ Missing unzip

Runtime Errors (exit code 1)
  ├─ Token not found
  ├─ Network unreachable
  ├─ Permission denied
  └─ AppImage corrupted

Process Errors (exit code 5)
  ├─ Claude already running
  └─ Failed to kill existing process
```

### Error Recovery

```
Error occurs
  |
  v
Log detailed error message
  |
  v
Suggest remediation
  ├─ "Install: sudo dnf install X"
  ├─ "Check: $file"
  ├─ "Run: scripts/tools/claude-auth-diagnostics.sh"
  └─ "See: docs/troubleshooting.md"
  |
  v
Exit with appropriate code
```

## CI/CD Infrastructure

### GitHub Actions
- **ShellCheck** - Lint all shell scripts for common issues
- **Test Build Scripts** - Verify build process on each PR
- **Release Workflow** - Auto-publish releases with checksums

### SPDX License Headers
All shell scripts include Apache-2.0 SPDX identifier and license text.

### Contributing Guidelines
CONTRIBUTING.md defines PR process, code style, and issue reporting standards.

## Future Extension Points

1. **Auto-Update UI** - Integrated update notifier instead of console
2. **Multiple Versions** - Keep multiple AppImage versions, switch on demand
3. **Plugin System** - Load custom extensions from ~/.config/Claude/plugins
4. **Sandbox/Confinement** - Use AppArmor or Seccomp for security
5. **Package Managers** - RPM/DEB integration for system package managers
6. **Container Support** - Docker/Podman Dockerfile for isolated environments
7. **Expanded Platform Support** - Ubuntu, Debian, openSUSE, Alpine

---

**Last Updated**: 2026-03-19
