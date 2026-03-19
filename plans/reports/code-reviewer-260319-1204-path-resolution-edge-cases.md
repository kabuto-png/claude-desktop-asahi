# Path Resolution Edge Cases Review

**Date:** 2026-03-19
**Scope:** Script reorganization from root to `scripts/{builders,launcher,tools,version}/`
**Files Reviewed:** 4 critical scripts
**Status:** Issues Found

---

## Executive Summary

Scripts were reorganized into subdirectories but maintain hardcoded relative path references to `./build-appimage.sh` that **break when executed from their new locations**. Additional issues found with outdated URL references and potential script sourcing failures.

---

## Detailed Findings

### 1. ❌ scripts/version/check_latest_version.sh — UNHANDLED

**Issue:** Lines 30, 37 reference `./build-appimage.sh` with relative path.

```bash
Line 30: echo "ℹ️  Run ./build-appimage.sh to build version $LATEST"
Line 37: echo "  3. Run: ./build-appimage.sh --claude-download-url <new-url>"
```

**Problem:** Script is in `scripts/version/` but `build-appimage.sh` is at project root. When user follows instruction to `Run ./build-appimage.sh`, execution from `scripts/version/` will fail with **file not found**.

**Impact:** High - Documentation directs users to run a non-existent script path.

**Fix Required:**
```bash
# Instead of:
echo "ℹ️  Run ./build-appimage.sh to build version $LATEST"

# Use:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "ℹ️  Run $PROJECT_ROOT/build-appimage.sh to build version $LATEST"
# OR
echo "ℹ️  Run ../../build-appimage.sh to build version $LATEST (from scripts/version/)"
```

**Status:** ❌ **UNHANDLED**

---

### 2. ❌ scripts/version/investigate_version_sources.sh — UNHANDLED

**Issue:** Line 10 references `./build-appimage.sh` with relative path.

```bash
Line 10: echo "No build directory found. Run ./build-appimage.sh first."
```

**Problem:** Same as above. Script is in `scripts/version/` but message directs user to `./build-appimage.sh` which doesn't exist from that location. The check at line 9 only verifies if `build/` exists, not if `build-appimage.sh` can be found.

**Impact:** High - Users cannot follow error recovery instructions.

**Fix Required:**
```bash
# Current (broken):
if [ ! -d build ]; then
    echo "No build directory found. Run ./build-appimage.sh first."
    exit 1
fi

# Fixed:
if [ ! -d build ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    echo "No build directory found. Run $PROJECT_ROOT/build-appimage.sh first."
    exit 1
fi
```

**Status:** ❌ **UNHANDLED**

---

### 3. ⚠️ scripts/builders/fedora_asahi_build_script.sh — PARTIAL ISSUE

**Issue:** Line 24 contains **hardcoded download URL with specific version (1.0.1307)**.

```bash
Line 24: CLAUDE_DOWNLOAD_URL="https://downloads.claude.ai/releases/win32/arm64/1.0.1307/Claude-1ed8835ce5539ba2a894ab752752be672a17c0d8.exe"
```

**Problem:** While not a path resolution issue, this is a stale reference. Version 1.0.1307 is outdated; the project currently builds 1.1.7464 and later. Users running this script will get an old version instead of the latest.

**Impact:** Medium - Inconsistent with project's current version targeting.

**Related Context:**
- Script accepts `--claude-download-url` parameter to override (lines 30-32) ✅
- Root `build-appimage.sh` likely has updated URL
- Version detection later in script (line 226-236) works correctly

**Recommendation:** Either:
1. Remove hardcoded URL and require `--claude-download-url` parameter
2. Auto-fetch latest URL from official sources
3. Document that this URL is a fallback and users should update it

**Status:** ⚠️ **PARTIAL** - Has override mechanism but default is stale

---

### 4. ✅ scripts/launcher/claude-launcher.sh — HANDLED CORRECTLY

**Finding:** Path resolution is **correct and well-designed**.

```bash
Line 9:  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Line 10: APPIMAGE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

**Analysis:**
- ✅ Correctly resolves script location via `${BASH_SOURCE[0]}`
- ✅ Correctly computes parent directories (/../..)
- ✅ All subsequent path references use `$APPIMAGE_DIR` as base

**Script Sourcing Check:**
```bash
Line 16: VERSION_CHECKER_SCRIPT="$APPIMAGE_DIR/scripts/version/check-official-version.sh"
Lines 265-268: Correctly sources if file exists with fallback
```

**Status:** ✅ **HANDLED** - Exemplary implementation. This is the pattern other scripts should follow.

---

## Cross-Script Path Dependencies

| Script | Requires | Resolution | Status |
|--------|----------|-----------|--------|
| check_latest_version.sh | build-appimage.sh (output only) | Broken hardcoded path | ❌ |
| investigate_version_sources.sh | build-appimage.sh (error message) | Broken hardcoded path | ❌ |
| fedora_asahi_build_script.sh | CLAUDE_DOWNLOAD_URL | Stale default | ⚠️ |
| claude-launcher.sh | check-official-version.sh | Dynamic path resolution | ✅ |

---

## Recommended Fixes (Priority Order)

### P1: Critical Path Breakage

**File:** `scripts/version/check_latest_version.sh`
**Action:** Add path resolution header and update all `./build-appimage.sh` references

```bash
#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Check if there's a newer Claude Desktop version available

# Resolve paths (new)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_SCRIPT="$PROJECT_ROOT/build-appimage.sh"

echo "=== Claude Desktop Version Checker ==="
echo ""

# ... existing code ...

# Line 30 becomes:
if [ -z "$CURRENT_VERSION" ]; then
    echo "ℹ️  Run $BUILD_SCRIPT to build version $LATEST"
fi

# Line 37 becomes:
echo "  3. Run: $BUILD_SCRIPT --claude-download-url <new-url>"
```

**File:** `scripts/version/investigate_version_sources.sh`
**Action:** Add path resolution header and update error message

```bash
#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Investigate all possible version sources in Claude Desktop installer

# Resolve paths (new)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_SCRIPT="$PROJECT_ROOT/build-appimage.sh"

echo "=== Investigating Claude Desktop Version Sources ==="
echo ""

# Check if we have a build directory
if [ ! -d "$PROJECT_ROOT/build" ]; then
    echo "No build directory found. Run $BUILD_SCRIPT first."
    exit 1
fi

cd "$PROJECT_ROOT/build"
# ... rest of script unchanged ...
```

### P2: Stale Version Reference

**File:** `scripts/builders/fedora_asahi_build_script.sh`
**Action:** Either remove hardcoded URL or document it as deprecated

**Option A (Recommended):** Make download URL required
```bash
# Remove line 24 and update help:
while [[ $# -gt 0 ]]; do
    case $1 in
        --claude-download-url)
            CLAUDE_DOWNLOAD_URL="$2"
            shift 2
            ;;
        *)
            # ... help text ...
            echo "  --claude-download-url <url>  URL to download Claude installer (REQUIRED)"
            exit 1
            ;;
    esac
done

# Add validation:
if [ -z "$CLAUDE_DOWNLOAD_URL" ]; then
    echo "Error: --claude-download-url is required"
    exit 1
fi
```

**Option B (Less Disruptive):** Update to latest known version
```bash
# Update line 24 to latest version in project (1.1.7464)
CLAUDE_DOWNLOAD_URL="https://downloads.claude.ai/releases/win32/arm64/1.1.7464/Claude-<hash>.exe"
# Note: This becomes stale again. Option A is better long-term.
```

---

## Testing Verification

### Test 1: Execute check_latest_version.sh from scripts/version/
```bash
cd /path/to/project/scripts/version/
bash check_latest_version.sh
# Expected: Should show correct path to build-appimage.sh or absolute reference
# Current: Shows broken path
```

### Test 2: Execute investigate_version_sources.sh from scripts/version/
```bash
cd /path/to/project/scripts/version/
bash investigate_version_sources.sh
# Expected: Should find build directory relative to project root
# Current: Looks for build/ relative to scripts/version/ (fails)
```

### Test 3: Execute claude-launcher.sh from different locations
```bash
# From project root
scripts/launcher/claude-launcher.sh
# From home directory
/path/to/project/scripts/launcher/claude-launcher.sh
# Expected: Both work (finds AppImage in project root)
# Current: ✅ Works correctly
```

### Test 4: Version checker script sourcing
```bash
bash -x scripts/launcher/claude-launcher.sh --help 2>&1 | grep -i "version"
# Expected: No errors sourcing check-official-version.sh
# Current: ✅ Should work (file exists and path is correct)
```

---

## Impact Assessment

| Area | Severity | User Impact |
|------|----------|------------|
| Direct execution paths | High | Users cannot follow error messages |
| Documentation clarity | High | Instructions reference non-existent paths |
| Version freshness | Medium | Users get outdated Claude Desktop |
| Architecture patterns | Low | Inconsistent approach across scripts |

---

## Code Quality Observations

### Positive
- ✅ `claude-launcher.sh` demonstrates best practice for path resolution
- ✅ Error handling and fallbacks in launcher script
- ✅ Configuration variables clearly declared
- ✅ Comments explain complex logic

### Issues
- ❌ Inconsistent path resolution patterns across scripts
- ❌ Hardcoded relative paths assume execution context
- ❌ No validation that referenced scripts exist before suggesting their use
- ⚠️ Version URLs should be externalized or auto-fetched

---

## Unresolved Questions

1. **Version URL Management:** Is there a central source-of-truth for Claude Desktop download URLs (beyond hardcoding)?
2. **Script Execution Context:** Are users expected to run these scripts from specific directories? Should this be documented?
3. **Build Script:** Should `build-appimage.sh` be moved to `scripts/builders/` for consistency, or kept at root for discoverability?
4. **Path Portability:** Should scripts be runnable from any working directory, or only from their designated locations?

---

## Conclusion

**Grade: C+**

The path reorganization was incomplete. While the launcher script implements correct path resolution patterns, the version scripts still use brittle relative paths. This creates a poor user experience when scripts provide error messages directing users to run unavailable script locations.

**Recommended Action:** Apply P1 fixes immediately (15 min work), then evaluate architecture consistency (whether to centralize path resolution patterns).
