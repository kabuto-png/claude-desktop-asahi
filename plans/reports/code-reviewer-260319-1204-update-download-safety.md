# Code Review: Update/Download Safety Edge Cases

**Date:** 2026-03-19
**Focus:** Partial download recovery, disk full handling, cross-device moves, URL mismatches, file size validation
**Files Reviewed:**
- `/home/longne/syncthings/Documents/claude-desktop-to-appimage/scripts/launcher/claude-launcher.sh` (lines 314-420)
- `/home/longne/syncthings/Documents/claude-desktop-to-appimage/scripts/version/check-official-version.sh`
- `/home/longne/syncthings/Documents/claude-desktop-to-appimage/build-appimage.sh`

---

## Executive Summary

**Overall Assessment:** ⚠️ **Partial** — Safety mechanisms exist but have critical gaps in disk full handling, partial download cleanup, and URL mismatch detection.

**Critical Issues:** 1 (URL mismatch, broken fallback chain)
**High Priority:** 2 (Disk full, partial download cleanup)
**Medium Priority:** 1 (File size validation threshold)

---

## Edge Case Analysis

### 1. Partial Download — Temp File Cleanup on Interrupt

**Scope:** Lines 362-386 in `claude-launcher.sh`

**Code:**
```bash
local TEMP_APPIMAGE="/tmp/Claude_Desktop-${LATEST_VERSION}-aarch64.AppImage.tmp"

if curl -L -f --progress-bar -o "$TEMP_APPIMAGE" "$DOWNLOAD_URL" 2>/dev/null; then
    # ... verify & move
else
    log_warn "Download failed. Continuing with current version."
    rm -f "$TEMP_APPIMAGE" 2>/dev/null
fi
```

**Assessment:**

✅ **Partially Handled:**
- Cleanup trap exists at line 36: `trap 'cleanup_on_exit' EXIT INT TERM`
- Trap function (lines 39-44) removes `$LOCK_FILE` but **NOT** temp download files
- Explicit cleanup at line 385 removes temp file on failed download

❌ **Unhandled:**
- **If curl is killed mid-download (SIGKILL, OOM, timeout >10s), the trap doesn't remove `/tmp/Claude_Desktop-*.tmp`** — only `$LOCK_FILE` is cleaned
- Trap fires on EXIT/INT/TERM, but:
  - `cleanup_on_exit()` doesn't reference `$TEMP_APPIMAGE` (undefined in that scope)
  - No mechanism to track which temp files belong to this session
  - Orphaned `.tmp` files persist in `/tmp` indefinitely

⚠️ **Risk:** `/tmp` accumulates stale temp downloads from interrupted runs. On long-running systems, this wastes disk space.

**Recommendation:**
```bash
# At script start, define globally:
TEMP_APPIMAGE=""

# In cleanup_on_exit:
cleanup_on_exit() {
    log_info "Script interrupted - cleaning up..."
    rm -f "$LOCK_FILE" 2>/dev/null || true
    if [ -n "$TEMP_APPIMAGE" ]; then
        rm -f "$TEMP_APPIMAGE" 2>/dev/null || true
    fi
}

# In download section:
TEMP_APPIMAGE="/tmp/Claude_Desktop-${LATEST_VERSION}-aarch64.AppImage.tmp"
if curl -L -f --progress-bar -o "$TEMP_APPIMAGE" "$DOWNLOAD_URL" 2>/dev/null; then
    # ...
```

---

### 2. Disk Full — Graceful Failure

**Scope:** Lines 364-372 in `claude-launcher.sh`

**Code:**
```bash
if curl -L -f --progress-bar -o "$TEMP_APPIMAGE" "$DOWNLOAD_URL" 2>/dev/null; then
    FILE_SIZE=$(stat -c%s "$TEMP_APPIMAGE" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -lt 1048576 ]; then
        log_error "Downloaded file too small..."
```

**Assessment:**

❌ **Unhandled:**
- **curl silently succeeds but writes 0 bytes or partial file if `/tmp` is full**
  - `curl -f` fails only on HTTP errors (4xx, 5xx), not I/O errors
  - Writing to full disk: curl may exit 0 even with truncated output
- **File size check (1MB) may pass truncated files if download > 1MB before disk filled**
  - A 50MB AppImage truncated to 10MB passes the 1MB check
- **No attempt to check `/tmp` disk space before download**

⚠️ **Risk:** Corrupted/truncated AppImage accepted → installation fails at runtime. User doesn't know why.

**Example Failure Path:**
```
1. /tmp has 100MB free, download starts (200MB file)
2. At 110MB written, disk full → curl silently truncates
3. File size check: 110MB > 1MB ✓ PASS
4. Move to $NEW_APPIMAGE_PATH succeeds
5. Later: AppImage launch fails with obscure FUSE errors
```

**Recommendation:**
```bash
# Before download, check /tmp space:
check_disk_space_before_download() {
    local required_size=${1:-300000000}  # 300MB default
    local available=$(df /tmp | tail -1 | awk '{print $4 * 1024}')

    if [ "$available" -lt "$required_size" ]; then
        log_error "Insufficient disk space in /tmp: $(( available / 1024 / 1024 ))MB available, ${required_size} bytes required"
        return 1
    fi
    return 0
}

# Before curl:
if ! check_disk_space_before_download 300000000; then
    return 0
fi

# Validate output more robustly:
if curl -L -f --progress-bar -o "$TEMP_APPIMAGE" "$DOWNLOAD_URL" 2>/dev/null; then
    # Check if curl actually completed (not killed by disk full)
    if [ ! -s "$TEMP_APPIMAGE" ]; then
        log_error "Download produced empty file (disk full?)"
        rm -f "$TEMP_APPIMAGE"
        return 0
    fi

    FILE_SIZE=$(stat -c%s "$TEMP_APPIMAGE" 2>/dev/null || echo "0")
    # More lenient check: AppImage > 20MB (most are 80-150MB)
    if [ "$FILE_SIZE" -lt 20971520 ]; then
        log_error "Downloaded file too small (${FILE_SIZE} bytes, truncated?)"
        rm -f "$TEMP_APPIMAGE"
        return 0
    fi
```

---

### 3. Cross-Device Move — Filesystem Boundary Issues

**Scope:** Line 377 in `claude-launcher.sh`

**Code:**
```bash
mkdir -p "$APPIMAGE_DIR"
mv "$TEMP_APPIMAGE" "$NEW_APPIMAGE_PATH"
```

**Assessment:**

⚠️ **Partially Handled:**
- `mkdir -p` ensures target directory exists
- `mv` is used (atomic on same filesystem, but fails across filesystems)

❌ **Unhandled:**
- **If `/tmp` and `$APPIMAGE_DIR` are on different filesystems, `mv` fails without error handling**
  - Common when:
    - `/tmp` on tmpfs (RAM)
    - Project dir on network mount or external drive
    - Docker container with separate mounts
- **No retry with `cp + rm` fallback**
- **No error message if move fails silently**

⚠️ **Risk:** Move fails → `$TEMP_APPIMAGE` left in `/tmp`, script assumes success and sets `APPIMAGE_PATH` to non-existent file.

**Example Failure Path:**
```
1. /tmp is tmpfs, project in /mnt/nfs
2. mv /tmp/Claude...tmp /mnt/nfs/Claude...AppImage
   → FAILS (cross-device link error)
3. Script logs "Download complete. Installing..."
4. APPIMAGE_PATH set to /mnt/nfs/Claude...AppImage (doesn't exist!)
5. Later: "AppImage not found" error
```

**Current Code (lines 374-379):**
```bash
if curl -L -f --progress-bar -o "$TEMP_APPIMAGE" "$DOWNLOAD_URL" 2>/dev/null; then
    # ... size check ...

    log_info "Download complete. Installing..."
    mkdir -p "$APPIMAGE_DIR"
    mv "$TEMP_APPIMAGE" "$NEW_APPIMAGE_PATH"  # ← NO ERROR CHECK!
    chmod +x "$NEW_APPIMAGE_PATH"
    log_info "Updated to v$LATEST_VERSION"
```

**Recommendation:**
```bash
# Atomic move with fallback:
move_temp_appimage() {
    local src="$1" dst="$2"

    if ! mv "$src" "$dst" 2>/dev/null; then
        log_warn "Cross-filesystem move detected, using copy+delete..."
        if cp "$src" "$dst" 2>/dev/null; then
            rm -f "$src"
            return 0
        else
            log_error "Failed to move/copy AppImage to $dst"
            return 1
        fi
    fi
    return 0
}

# Usage:
if curl ... && [ "$FILE_SIZE" -ge 1048576 ]; then
    log_info "Download complete. Installing..."
    mkdir -p "$APPIMAGE_DIR"
    if ! move_temp_appimage "$TEMP_APPIMAGE" "$NEW_APPIMAGE_PATH"; then
        rm -f "$TEMP_APPIMAGE"
        return 0
    fi
    chmod +x "$NEW_APPIMAGE_PATH"
```

---

### 4. URL Mismatch — `.nupkg` vs `.exe` vs AppImage

**Scope:** `check-official-version.sh` lines 141-165 vs `claude-launcher.sh` lines 304-313

**Issue:** **`get_latest_download_url()` can return `.nupkg` (Windows Squirrel format) but code expects `.AppImage`**

**Analysis:**

**In `check-official-version.sh` (lines 141-165):**
```bash
get_latest_download_url() {
    # Try GitHub release asset (most reliable for AppImage)
    local url
    url=$(get_github_download_url)
    if [ -n "$url" ]; then
        echo "$url"  # ✅ Returns .AppImage
        return 0
    fi

    # Fallback: construct nupkg URL from RELEASES endpoint
    releases_content=$(curl -sf ... "$RELEASES_URL" 2>/dev/null)
    if [ -n "$releases_content" ]; then
        local nupkg
        nupkg=$(echo "$releases_content" | tail -1 | awk '{print $2}')  # ✅ Extracts nupkg filename
        # ...
        echo "https://downloads.claude.ai/releases/win32/arm64/${version}/${nupkg}"  # ❌ WRONG FORMAT!
        return 0
    fi
    return 1
}
```

❌ **Critical Problem:**
1. **Primary (GitHub): Returns `.AppImage` URL** ✅
2. **Fallback (Anthropic RELEASES): Returns `.nupkg` URL** ❌
   - Example: `https://downloads.claude.ai/releases/win32/arm64/1.47.0/AnthropicClaude-1.47.0-full.nupkg`
   - `.nupkg` is Windows Squirrel installer format, not AppImage
   - Downloading `.nupkg` → `curl` succeeds but file is wrong format
3. **File size check** (1MB) still passes (`.nupkg` ~100MB+)
4. **`chmod +x`** on `.nupkg` succeeds (file exists)
5. **`launch_claude`** tries to execute `.nupkg` → **SILENT FAILURE**

**Fallback Chain Broken:**

| Source | URL Type | Format | Usable |
|--------|----------|--------|---------|
| GitHub (primary) | `.AppImage` | AppImage | ✅ Yes |
| Anthropic RELEASES (fallback) | `.nupkg` | Windows installer | ❌ No (Linux) |

**Risk:** If GitHub is down/rate-limited, fallback silently downloads wrong file type → launcher fails mysteriously.

**Current Flow in `claude-launcher.sh` (lines 304-313):**
```bash
get_download_url() {
    if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
        return 1
    fi

    curl -sf ... \
        | jq -r '.assets[] | select(.name | contains("arm64.AppImage") ...) | .browser_download_url' \
        | head -1
}
```
This function **only queries GitHub API** (no fallback to RELEASES), so it's safer. But `check-official-version.sh` is used elsewhere and has the broken fallback.

**Recommendation:**

**Option A (Safe):** Remove `.nupkg` fallback entirely, require AppImage:
```bash
get_latest_download_url() {
    # GitHub only (no nupkg fallback)
    local url
    url=$(get_github_download_url)
    if [ -n "$url" ]; then
        echo "$url"
        return 0
    fi

    log_error "Could not find AppImage download URL (GitHub unavailable)"
    return 1
}
```

**Option B (Robust):** Validate URL before downloading:
```bash
is_appimage_url() {
    local url="$1"
    [[ "$url" =~ \.AppImage$ || "$url" =~ \.AppImage\.tmp$ ]]
}

# In download section:
DOWNLOAD_URL=$(get_download_url)
if ! is_appimage_url "$DOWNLOAD_URL"; then
    log_error "Invalid download URL (not AppImage): $DOWNLOAD_URL"
    return 0
fi
```

---

### 5. File Size Check — 1MB Threshold Too Low

**Scope:** Lines 365-372 in `claude-launcher.sh`

**Code:**
```bash
FILE_SIZE=$(stat -c%s "$TEMP_APPIMAGE" 2>/dev/null || echo "0")
if [ "$FILE_SIZE" -lt 1048576 ]; then  # 1MB
    log_error "Downloaded file too small (${FILE_SIZE} bytes). Discarding."
```

**Assessment:**

⚠️ **Partial Risk:**
- **Claude Desktop AppImage is ~80-150MB** (as of v1.47.0)
- **1MB threshold is too low** — could accept severely truncated files
  - 10MB partial download passes check
  - Still blocks obvious corruptions (0 bytes, network timeout with no output)

✅ **Handles:** Downloads that produce 0-byte or <1MB files (partial network disconnects)

❌ **Misses:**
- Truncated downloads: 10MB < 80MB → passes 1MB check but AppImage won't launch
- No upper bound check (protects against accidentally downloading 1GB+ file)
- No checksum validation (can't detect silent corruption)

**Realistic Failure Path:**
```
1. Download starts: curl -L -f -o /tmp/Claude...tmp DOWNLOAD_URL
2. At 50MB downloaded, network drops
3. curl times out, but already wrote 50MB to disk
4. File size check: 50MB > 1MB ✅ PASS
5. AppImage launch: FUSE mount fails → "corrupted binary"
```

**Recommendation:**

```bash
# More realistic minimum size (current AppImage is ~80MB):
MINIMUM_APPIMAGE_SIZE=$((50 * 1024 * 1024))  # 50MB (safety margin below typical)
MAXIMUM_APPIMAGE_SIZE=$((500 * 1024 * 1024)) # 500MB (upper sanity bound)

FILE_SIZE=$(stat -c%s "$TEMP_APPIMAGE" 2>/dev/null || echo "0")

if [ "$FILE_SIZE" -lt "$MINIMUM_APPIMAGE_SIZE" ]; then
    log_error "Downloaded file too small (${FILE_SIZE} bytes, min ${MINIMUM_APPIMAGE_SIZE}). Truncated?"
    rm -f "$TEMP_APPIMAGE"
    return 0
fi

if [ "$FILE_SIZE" -gt "$MAXIMUM_APPIMAGE_SIZE" ]; then
    log_error "Downloaded file suspiciously large (${FILE_SIZE} bytes, max ${MAXIMUM_APPIMAGE_SIZE}). Aborting."
    rm -f "$TEMP_APPIMAGE"
    return 0
fi
```

Alternatively, **add SHA256 checksum validation** if Anthropic publishes it (most reliable).

---

## Summary Table

| Edge Case | Status | Severity | Fix Required |
|-----------|--------|----------|--------------|
| 1. Partial download cleanup | ⚠️ Partial | High | Yes — trap doesn't clean `.tmp` files |
| 2. Disk full handling | ❌ Unhandled | Critical | Yes — no pre-check, no validation |
| 3. Cross-device move | ⚠️ Partial | High | Yes — no error handling, no fallback |
| 4. URL mismatch (nupkg) | ❌ Unhandled | Critical | Yes — fallback returns wrong format |
| 5. File size threshold | ⚠️ Partial | Medium | Optional — 1MB too low for 80MB file |

---

## Recommended Action Priority

1. **CRITICAL (Do First):** Fix disk full handling + cross-device move (#2, #3)
2. **HIGH (Do Second):** Trap cleanup for temp files (#1) + URL validation (#4)
3. **MEDIUM (Polish):** Adjust file size thresholds (#5)

---

## Code Quality Observations

**Positive:**
- Cleanup trap structure exists (foundational)
- Temp file in `/tmp` prevents pollution of project dir
- Explicit error cleanup on download failure
- Version comparison logic sound

**Negative:**
- Error handling incomplete (missing critical paths)
- No validation of fallback URLs
- No disk space pre-flight check
- Trap function not scoped to track temp files
- Silent failures (move, disk full) not logged

---

## Unresolved Questions

1. What's the typical AppImage size for Claude Desktop v1.47.0? (Set threshold accordingly)
2. Does Anthropic publish checksums for releases?
3. Is the GitHub fallback preferred over Anthropic RELEASES endpoint, or both needed?
4. Should update check run asynchronously to avoid blocking launcher?
