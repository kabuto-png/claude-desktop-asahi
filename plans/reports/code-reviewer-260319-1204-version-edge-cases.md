# Code Review: Version Detection Edge Cases
## check-official-version.sh

**Date**: 2026-03-19
**Reviewer**: code-reviewer
**File**: `scripts/version/check-official-version.sh`
**Focus**: Edge case handling in version detection logic

---

## Summary

Script implements version detection fallback chain (cache → official endpoint → GitHub API) with **3 critical unhandled edge cases** and **1 partial handling**. Needs defensive programming improvements.

---

## Edge Case Analysis

### 1. Cache File Corruption: Non-numeric Timestamp
**Location**: Lines 11-28 (`get_cached_version()`)

**Issue**: Line 21 performs arithmetic comparison without type validation:
```bash
cache_time=$(head -1 "$CACHE_FILE" 2>/dev/null)
if [ -z "$cache_time" ] || [ $((current_time - cache_time)) -ge $CACHE_TTL ]; then
```

**What Happens**:
- If first line contains `"not-a-timestamp"`, bash arithmetic `$((current_time - cache_time))` **expands to 0**
- This **silently passes** the age check (0 < 86400 = true)
- Invalid timestamp treated as "just cached", returns corrupted version

**Status**: ❌ **UNHANDLED**

**Impact**: HIGH - User gets invalid cached version indefinitely until manual cache clear

**Example**:
```bash
# Cache file contains:
# not-a-timestamp
# 1.0.1234
cache_time="not-a-timestamp"
$((1234567890 - not-a-timestamp))  # Expands to: 1234567890 - 0 = 1234567890
# Passes check since 1234567890 >= 86400 = true (!)
```

**Fix Required**:
```bash
# Validate cache_time is numeric before arithmetic
if ! [[ $cache_time =~ ^[0-9]+$ ]]; then
    echo "ERROR: Corrupted cache file (invalid timestamp)" >&2
    rm -f "$CACHE_FILE"
    return 1
fi
```

---

### 2. Four-Part Version Format (1.0.1307.0)
**Location**: Lines 48, 75, 157 (three regex patterns)

**Issue**: All version regex patterns use `[0-9]+\.[0-9]+\.[0-9]+` which matches only 3-part versions:

```bash
# Line 48: Official RELEASES endpoint
version=$(echo "$releases_content" | tail -1 | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+')

# Line 75: GitHub asset name parsing
version=$(... | grep -oP 'claude-desktop-\K[0-9]+\.[0-9]+\.[0-9]+')

# Line 157: RELEASES nupkg version extraction
version=$(echo "$nupkg" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+')
```

**What Happens**:
- If official RELEASES contains `AnthropicClaude-1.0.1307.0-full.nupkg`, regex matches **only `1.0.1307`**
- 4th version part (0) is silently dropped
- Creates mismatch between detected version and actual filename

**Example**:
```
RELEASES content:
abc123def AnthropicClaude-1.0.1307.0-full.nupkg 5242880

Matched: 1.0.1307  (missing .0)
Filename: AnthropicClaude-1.0.1307.0-full.nupkg  (has .0)
```

**Status**: ⚠️ **PARTIAL** - Matches 3-part but silently truncates 4+ parts

**Impact**: MEDIUM - Version number mismatch, filename construction fails (line 159)

**Current Behavior**:
- Line 159 tries to construct URL: `https://downloads.claude.ai/releases/win32/arm64/${version}/${nupkg}`
- With version=1.0.1307 and nupkg=AnthropicClaude-1.0.1307.0-full.nupkg
- URL becomes: `.../1.0.1307/AnthropicClaude-1.0.1307.0-full.nupkg` → **404 Not Found**

**Fix Required** (all three locations):
```bash
# Matches 3-part (X.Y.Z) or 4-part (X.Y.Z.W)
version=$(echo "$releases_content" | tail -1 | grep -oP 'AnthropicClaude-\K[0-9]+(\.[0-9]+)+')
```

---

### 3. RELEASES Endpoint Format Change
**Location**: Lines 38-56 (`check_official_version()`) and lines 151-162 (`get_latest_download_url()`)

**Issue**: No fallback if RELEASES endpoint format changes; assumptions hardcoded:
```bash
# Line 46-48: Assumes last line has "AnthropicClaude-" prefix
version=$(echo "$releases_content" | tail -1 | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+')

# Line 155: Assumes field 2 is nupkg filename
nupkg=$(echo "$releases_content" | tail -1 | awk '{print $2}')
```

**What Happens**:
- If Anthropic changes RELEASES format (e.g., adds header, changes delimiter, different field order)
- Last line may NOT contain `AnthropicClaude-`
- Regex fails silently, `version` becomes empty string
- Function returns 1, falls back to GitHub (OK, but inefficient)

**Example 1 - Format change**:
```
Original RELEASES (2024):
a1b2c3d4 AnthropicClaude-1.0.1307-full.nupkg 5242880

New format (hypothetical 2025):
release: v1.0.1307 AnthropicClaude-1.0.1307-full.nupkg
Parsed version: "" (empty, "release:" doesn't match)
```

**Example 2 - Missing prefix on last line**:
```
abc123 AnthropicClaude-1.0.1306-full.nupkg 5242880
--- Last stable release ---
Parsed version: "" (hyphen line has no prefix)
```

**Status**: ⚠️ **PARTIAL** - Graceful fallback exists (checks != empty, line 42), but no error logging

**Impact**: MEDIUM - Silent degradation to GitHub API (rate-limited), no visibility into why

**Current Safety**:
- Line 42: `if [ -z "$releases_content" ]; then return 1` ✓ Catches curl failure
- Line 50: `if [ -n "$version" ]; then` ✓ Catches regex failure
- **Missing**: No distinction between "endpoint unreachable" vs "format changed"

**Improvement Needed**:
```bash
# Log which check failed for debugging
if [ -z "$releases_content" ]; then
    echo "[DEBUG] RELEASES endpoint unreachable" >&2
    return 1
fi

if [ -z "$version" ]; then
    echo "[DEBUG] RELEASES format unrecognized (no match for 'AnthropicClaude-' in last line)" >&2
    return 1
fi
```

---

### 4. GitHub API Rate Limit (403 Forbidden)
**Location**: Lines 59-83 (`check_github_version()`), lines 86-109 (`get_github_download_url()`)

**Issue**: curl -sf suppresses error output but doesn't distinguish HTTP error types:

```bash
# Line 67:
release_info=$(curl -sf --connect-timeout 5 --max-time 10 "$github_api" 2>/dev/null)

# If 403 Forbidden (rate limit):
# - curl -sf returns rc=22 (HTTP error)
# - Error output suppressed by 2>/dev/null
# - $release_info becomes empty string
# - Function returns 1 (generic "failed")
```

**What Happens**:
- **60 requests/hour unauthenticated** limit per GitHub API docs
- When rate-limited, GitHub returns 403 Forbidden JSON:
  ```json
  {
    "message": "API rate limit exceeded for X.X.X.X",
    "documentation_url": "https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"
  }
  ```
- `curl -sf` returns empty stdout (json written to stderr, suppressed)
- `release_info=""`, function returns 1
- **No visibility** into why it failed

**Status**: ✅ **HANDLED** (functionally correct) but ⚠️ **PARTIAL** (no diagnostics)

**Impact**: LOW-MEDIUM - Fallback works (uses cache, re-tries later), but user sees generic "Failed to determine latest version" without rate-limit hint

**Current Behavior**:
- Line 69: `if [ -z "$release_info" ]; then return 1` ✓ Catches empty response
- Line 1: curl already times out at 5s → doesn't hang on network issues ✓
- **Missing**: Distinguish between network timeout, 403 rate limit, and other errors

**Example Diagnostic Output Needed**:
```bash
# User sees this error currently:
"Failed to determine latest version"

# Should see:
"Failed to determine latest version (GitHub API rate limit)"
# or
"Failed to determine latest version (network timeout)"
# or
"Failed to determine latest version (GitHub API returned unexpected format)"
```

**Enhancement Option**:
```bash
# Capture both stdout and stderr, check for rate limit message
response=$(curl -sf --connect-timeout 5 --max-time 10 "$github_api" 2>&1)
rc=$?
if [ $rc -eq 22 ]; then
    # HTTP error (could be 403, 404, etc.)
    if echo "$response" | grep -q "rate limit"; then
        echo "[WARN] GitHub API rate limited, retrying in 1 hour" >&2
        return 1
    fi
fi
```

---

## Summary Table

| Edge Case | Status | Impact | Fix Priority |
|-----------|--------|--------|--------------|
| 1. Cache corruption (non-numeric timestamp) | ❌ Unhandled | HIGH | CRITICAL |
| 2. 4-part version (1.0.1307.0) | ⚠️ Partial | MEDIUM | HIGH |
| 3. RELEASES format change | ⚠️ Partial | MEDIUM | MEDIUM |
| 4. GitHub API rate limit | ✅ Handled | LOW | LOW |

---

## Recommended Fixes (Priority Order)

### CRITICAL: Cache Corruption (Edge Case 1)
**Lines 11-28**: Add timestamp validation before arithmetic

```bash
get_cached_version() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    local cache_time
    cache_time=$(head -1 "$CACHE_FILE" 2>/dev/null)
    local current_time
    current_time=$(date +%s)

    # CRITICAL: Validate timestamp is numeric before arithmetic
    if ! [[ $cache_time =~ ^[0-9]+$ ]]; then
        echo "ERROR: Corrupted cache file (invalid timestamp: '$cache_time')" >&2
        rm -f "$CACHE_FILE"
        return 1
    fi

    if [ $((current_time - cache_time)) -ge $CACHE_TTL ]; then
        return 1
    fi

    # Return cached version (second line)
    sed -n '2p' "$CACHE_FILE"
    return 0
}
```

### HIGH: 4-Part Version Regex (Edge Case 2)
**Lines 48, 75, 157**: Update regex to match X.Y.Z or X.Y.Z.W or X.Y.Z.W.V...

```bash
# Pattern: [0-9]+(\.[0-9]+)+ matches any number of dot-separated numbers
# Examples: 1.0, 1.0.1307, 1.0.1307.0, 1.0.1307.0.1 all match

# Line 48:
version=$(echo "$releases_content" | tail -1 | grep -oP 'AnthropicClaude-\K[0-9]+(\.[0-9]+)+')

# Line 75:
version=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("arm64.AppImage") and (contains(".zsync") | not)) | .name' 2>/dev/null | head -1 | grep -oP 'claude-desktop-\K[0-9]+(\.[0-9]+)+')

# Line 157:
version=$(echo "$nupkg" | grep -oP 'AnthropicClaude-\K[0-9]+(\.[0-9]+)+')
```

### MEDIUM: Endpoint Format Robustness (Edge Case 3)
**Lines 38-56**: Add diagnostic logging for failures

```bash
check_official_version() {
    local releases_content
    releases_content=$(curl -sf --connect-timeout 5 --max-time 10 "$RELEASES_URL" 2>/dev/null)

    if [ -z "$releases_content" ]; then
        echo "[DEBUG] RELEASES endpoint unreachable or empty" >&2
        return 1
    fi

    # Parse version from last line: SHA AnthropicClaude-X.Y.Z-full.nupkg SIZE
    local version
    version=$(echo "$releases_content" | tail -1 | grep -oP 'AnthropicClaude-\K[0-9]+(\.[0-9]+)+')

    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi

    # Provide diagnostic hint
    echo "[DEBUG] RELEASES endpoint format unrecognized (last line: $(echo "$releases_content" | tail -1 | cut -c1-80)...)" >&2
    return 1
}
```

### LOW: GitHub Rate Limit Diagnostics (Edge Case 4)
**Lines 59-83**: Optional enhancement for better error messages

```bash
check_github_version() {
    local github_api="https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest"

    if ! command -v jq &>/dev/null; then
        return 1
    fi

    local release_info
    release_info=$(curl -sf --connect-timeout 5 --max-time 10 "$github_api" 2>/dev/null)

    if [ -z "$release_info" ]; then
        # Optional: try to detect rate limit in stderr
        local error_msg
        error_msg=$(curl -s --connect-timeout 5 --max-time 10 "$github_api" 2>&1 | grep -o "rate limit" || true)
        if [ -n "$error_msg" ]; then
            echo "[WARN] GitHub API rate limited, falling back to cache" >&2
        fi
        return 1
    fi

    # ... rest unchanged
}
```

---

## Code Quality Observations

### Positive Patterns ✓
1. **Fallback chain** (cache → official → GitHub) is well-structured
2. **Timeout protection** (5s connect, 10s max) prevents hangs
3. **Error suppression** (2>/dev/null) keeps output clean for scripting
4. **Return codes** (0 success, 1 failure) follow standards

### Concerns ⚠️
1. **No input validation** on cached version before echoing
2. **No version format validation** in return statements
3. **Silent failures** make debugging difficult
4. **Arithmetic expansion** without prior type checking (bash-specific bug)

---

## Testing Recommendations

```bash
# Test 1: Cache corruption
echo "corrupt-timestamp" > ~/.cache/claude-desktop-version-cache
echo "1.0.1234" >> ~/.cache/claude-desktop-version-cache
source scripts/version/check-official-version.sh
get_cached_version  # Should return 1 (fail), not the corrupted version

# Test 2: 4-part version
echo "a1b2c3d AnthropicClaude-1.0.1307.0-full.nupkg 5242880" |
  grep -oP 'AnthropicClaude-\K[0-9]+(\.[0-9]+)+'  # Should match 1.0.1307.0

# Test 3: Format change resilience
echo "--- RELEASES (old format) ---" | tail -1 |
  grep -oP 'AnthropicClaude-\K[0-9]+(\.[0-9]+)+'  # Should fail gracefully

# Test 4: GitHub rate limit
timeout 2 curl -sf --connect-timeout 1 --max-time 2 \
  https://api.github.com/rate_limit 2>/dev/null || echo "Failed (expected)"
```

---

## Unresolved Questions

1. **Why only 3-part version in grep?** Was it deliberately limited to X.Y.Z format, or oversight?
2. **Cache TTL (86400s)**: Is 24 hours correct for version checks, or should it be shorter given daily releases?
3. **RELEASES endpoint stability**: Has Anthropic promised format stability, or is fallback the intended design?
4. **GitHub authentication**: Would token-based auth solve rate limit issues, or violate security practices?
5. **Temporary failures**: How long should the script retry on network errors before giving up?

---

**Recommendation**: Address CRITICAL cache corruption issue immediately. HIGH and MEDIUM improvements can follow in next review cycle.
