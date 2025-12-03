# Electron Bundling Fix

## Problem

If the persistent AppImage fails to launch with the error "Electron not found", it means Electron was not bundled during the build process.

### Symptoms
- Regular AppImage (e.g., `Claude_Desktop-1.0.1307-aarch64.AppImage`) works fine when run directly
- Persistent AppImage (e.g., `Claude_Desktop-1.0.1307-aarch64-persistent.AppImage`) is too small (< 10MB)
- Running via the launcher script (`claude-fixed-launcher-v2.sh` or `claude-desktop` alias) shows "Error: Electron not found"

### Root Cause
The persistent AppImage's `AppRun` script looks for Electron at:
```
$HERE/usr/lib/claude-desktop/node_modules/electron/dist/electron
```

If Electron wasn't bundled during the build, this path doesn't exist, causing the launch to fail.

## Solution

Follow these steps to rebuild with Electron properly bundled:

### Step 1: Clean up old builds (optional)
```bash
rm -f Claude_Desktop-*.AppImage
rm -rf build/
```

### Step 2: Build the AppImage with Electron bundled
The build script automatically bundles Electron by default on Fedora Asahi (see `ELECTRON_BUNDLED=1` in `fedora_asahi_build_script.sh:22`):

```bash
./build-appimage.sh
```

This will:
1. Download Claude Desktop installer
2. Extract the application
3. Bundle Electron from `node_modules/electron`
4. Create a ~116MB AppImage with Electron included

### Step 3: Add persistence
Once the regular AppImage is built with Electron, create the persistent version:

```bash
./add_persistence_simple.sh
```

This will:
1. Extract the regular AppImage
2. Modify the `AppRun` script to use persistent data directories
3. Rebuild as a persistent AppImage (~93MB)

### Step 4: Verify the fix
Check file sizes:
```bash
ls -lh Claude_Desktop-*.AppImage
```

You should see:
- Regular: `Claude_Desktop-1.0.1307-aarch64.AppImage` (~116MB)
- Persistent: `Claude_Desktop-1.0.1307-aarch64-persistent.AppImage` (~93MB)

If the persistent AppImage is less than 50MB, Electron was not bundled correctly.

### Step 5: Test the launcher
```bash
./claude-fixed-launcher-v2.sh
# or use the alias:
claude-desktop
```

Claude should launch successfully and use persistent data directories:
- Configuration: `~/.config/Claude/`
- App Data: `~/.local/share/Claude/`
- Cache: `~/.cache/Claude/`

## Verification

To verify Electron is bundled in the persistent AppImage:

```bash
./Claude_Desktop-*-persistent.AppImage --appimage-extract
ls -la squashfs-root/usr/lib/claude-desktop/node_modules/electron/dist/electron
rm -rf squashfs-root
```

If the `electron` binary exists and is ~190MB, Electron is properly bundled.

## Build Script Details

The `fedora_asahi_build_script.sh` has `ELECTRON_BUNDLED=1` set by default at line 22. This ensures Electron is always bundled on Fedora Asahi ARM64 systems for compatibility.

If you need to build WITHOUT Electron (not recommended), use:
```bash
./fedora_asahi_build_script.sh --no-bundle-electron
```

## Data Persistence

Once the fix is applied, your Claude Desktop data will persist in:
- `~/.config/Claude/` - User settings and configuration
- `~/.local/share/Claude/` - Application data
- `~/.cache/Claude/` - Cache files

Your chats and settings will survive AppImage updates and system restarts.
