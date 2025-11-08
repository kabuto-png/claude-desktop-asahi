# Version Detection in Claude Desktop AppImage Builder

This document explains how version detection works and which sources are most reliable.

## Version Sources (Ordered by Reliability)

### 1. **app.asar package.json** (Most Reliable) ✅

**Location**: `lib/net45/resources/app.asar` → `package.json`

**Why it's reliable**: This is the actual Electron application's package.json file. It contains the version that the app itself reports and displays.

**How to extract**:
```bash
# During build
asar extract lib/net45/resources/app.asar /tmp/extract
cat /tmp/extract/package.json | grep '"version"'
```

**Example**:
```json
{
  "name": "claude-desktop",
  "version": "0.14.10",
  "productName": "Claude"
}
```

**Used by**: `fedora_asahi_build_script.sh` (primary method)

### 2. **.nupkg Filename** (Fallback)

**Location**: `AnthropicClaude-<version>-full.nupkg`

**Why it's less reliable**: The filename is set by the build system and may not always match the actual app version if there's a packaging issue.

**How to extract**:
```bash
find . -name "AnthropicClaude-*.nupkg" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+(?=-full)'
```

**Used by**: Fallback in all scripts when app.asar extraction fails

### 3. **Desktop File Metadata** (Last Resort)

**Location**: `ClaudeDesktop.AppDir/claude-desktop.desktop`

**Field**: `X-AppImage-Version=<version>`

**Why it's least reliable**: This is written during the AppImage build process based on previous detection methods, so it's derivative.

**Used by**: `manual_appimage_builder.sh` when build artifacts are no longer available

## Current Implementation

### Main Build Script (`fedora_asahi_build_script.sh`)

```bash
# Step 1: Extract nupkg
7z x -y "$NUPKG_PATH"

# Step 2: Get version from app.asar package.json
TEMP_EXTRACT=$(mktemp -d)
asar extract lib/net45/resources/app.asar "$TEMP_EXTRACT"
VERSION=$(grep -oP '"version"\s*:\s*"\K[^"]+' "$TEMP_EXTRACT/package.json")

# Step 3: Fallback to nupkg filename if extraction failed
if [ -z "$VERSION" ]; then
    VERSION=$(basename "$NUPKG_PATH" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+(?=-full)')
fi
```

### Manual Builder (`manual_appimage_builder.sh`)

Uses multiple fallback methods since build artifacts may be partially cleaned:
1. Search for .nupkg file
2. Check desktop file metadata
3. Default to hardcoded version (0.14.10)

## Version Verification Tools

### Check Actual Version
```bash
./get_actual_version.sh
```

This script extracts the version from app.asar package.json - the definitive source.

### Investigate All Sources
```bash
./investigate_version_sources.sh
```

Shows all version information from various sources for debugging.

### Check Latest Available
```bash
./check_latest_version.sh
```

Compares your version against the latest available from community sources.

## Why Multiple Methods?

Different scenarios require different approaches:

1. **During initial build**: Use app.asar package.json (most accurate)
2. **After partial cleanup**: Use .nupkg filename (if build dir exists)
3. **Manual AppImage rebuild**: Use desktop file metadata (last resort)
4. **User wants to check**: Read AppImage filename or extract and check

## Common Issues

### Issue: Version mismatch between filename and content

**Symptom**: AppImage named `Claude_Desktop-0.9.3-aarch64.AppImage` contains version 0.14.10

**Cause**: Hardcoded version in `manual_appimage_builder.sh` (fixed in recent updates)

**Solution**: Rebuild using the updated scripts that auto-detect from app.asar

### Issue: Cannot determine version

**Symptom**: Script shows "Could not detect version"

**Causes**:
- `asar` tool not installed
- Build artifacts cleaned up
- Corrupted download

**Solutions**:
```bash
# Install asar
npm install -g asar

# Or rebuild from scratch
rm -rf build
./build-appimage.sh
```

## Best Practices

1. **Always use app.asar package.json** when available (during build)
2. **Store version in desktop file** for later reference
3. **Don't rely solely on filenames** - they can be renamed
4. **Verify after build** using `./check_appimage_version.sh`

## Technical Details

### app.asar Structure

```
app.asar/
├── package.json          # ← VERSION SOURCE
├── main.js
├── renderer/
├── node_modules/
└── resources/
```

### Version Field Format

Standard semantic versioning: `MAJOR.MINOR.PATCH`
- Example: `0.14.10`
- Major: 0 (pre-1.0 release)
- Minor: 14 (feature updates)
- Patch: 10 (bug fixes)

## Future Improvements

Potential enhancements for version detection:

1. **Auto-fetch latest URL**: Query API/webpage for newest download link
2. **Version validation**: Cross-reference multiple sources and warn on mismatch
3. **Changelog integration**: Fetch release notes for detected version
4. **Update notifications**: Alert when newer version available

---

**Last Updated**: January 2025
**Current Recommended Version**: 0.14.10
