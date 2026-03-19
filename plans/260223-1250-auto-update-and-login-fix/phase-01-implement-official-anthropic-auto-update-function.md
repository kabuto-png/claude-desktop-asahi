# Phase 1: Implement Official Anthropic Auto-Update Function

## Priority: High
## Status: Pending
## Estimated Time: 2 hours

## Overview

Replace the current GitHub-based update check with direct official Anthropic download detection.

## Key Insights from Research

1. **Official URL Pattern**: `https://downloads.claude.ai/releases/win32/arm64/{version}/Claude-{hash}.exe`
2. **Redirect URL**: `https://claude.ai/redirect/claudedotcom.v1.290130bf-1c36-4eb0-9a93-2410ca43ae53/api/desktop/win32/arm64/exe/latest/redirect`
3. **No public version API** - must parse redirect or installer
4. **CDN**: `storage.googleapis.com` (no Cloudflare protection)

## Requirements

### Functional
- [ ] Check official Anthropic downloads for latest version
- [ ] Compare with currently installed version
- [ ] Download and install updates automatically
- [ ] Fallback to GitHub repo if official check fails
- [ ] Cache version info to reduce API calls

### Non-Functional
- [ ] Update check completes in <10 seconds
- [ ] Atomic downloads (no partial files)
- [ ] User notification before/after update

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Update Check Flow                     │
├─────────────────────────────────────────────────────────┤
│  1. Check cache (24h TTL)                               │
│     ↓ cache miss                                        │
│  2. Try redirect URL (HEAD request)                     │
│     ↓ success → parse version from Location header     │
│     ↓ fail                                              │
│  3. Fallback: GitHub API check                          │
│     ↓                                                   │
│  4. Compare versions                                    │
│     ↓ newer available                                   │
│  5. Download to temp file → verify → move to final     │
│     ↓                                                   │
│  6. Update cache, notify user                           │
└─────────────────────────────────────────────────────────┘
```

## Related Code Files

### Files to Modify
- `claude-fixed-launcher-v2.sh` - Main launcher with update logic

### Files to Create
- `check-official-version.sh` - Dedicated version checker script

## Implementation Steps

### Step 1: Create Version Checker Script

Create `check-official-version.sh`:

```bash
#!/bin/bash
# Check official Anthropic downloads for latest Claude Desktop version

REDIRECT_URL="https://claude.ai/redirect/claudedotcom.v1.290130bf-1c36-4eb0-9a93-2410ca43ae53/api/desktop/win32/arm64/exe/latest/redirect"
CACHE_FILE="$HOME/.cache/claude-desktop-version-cache"
CACHE_TTL=86400  # 24 hours

check_official_version() {
    # Try to get redirect location
    local location=$(curl -sI -o /dev/null -w '%{redirect_url}' "$REDIRECT_URL" 2>/dev/null)

    if [ -n "$location" ]; then
        # Parse version from URL: .../arm64/1.0.1307/Claude-xxx.exe
        echo "$location" | grep -oP 'arm64/\K[0-9]+\.[0-9]+\.[0-9]+' | head -1
    fi
}

get_download_url() {
    curl -sI -o /dev/null -w '%{redirect_url}' "$REDIRECT_URL" 2>/dev/null
}
```

### Step 2: Update Launcher Script

Modify `claude-fixed-launcher-v2.sh`:

1. Add official URL constants
2. Replace `check_and_update_appimage()` function
3. Add version cache logic
4. Add fallback to GitHub

### Step 3: Add Download Verification

- Verify file size > 100MB
- Check file is valid executable
- Use atomic move (temp → final)

### Step 4: Add User Notifications

- Show "Checking for updates..." message
- Show "Updating to vX.Y.Z..." during download
- Show "Update complete!" after success

## Todo List

- [ ] Create `check-official-version.sh` script
- [ ] Add redirect URL parsing to launcher
- [ ] Implement version cache with 24h TTL
- [ ] Add atomic download with temp file
- [ ] Add fallback to GitHub repo
- [ ] Add progress indicator for downloads
- [ ] Test update flow end-to-end
- [ ] Update README with new update behavior

## Success Criteria

1. `./check-official-version.sh` returns latest version number
2. Launcher detects new versions within 10 seconds
3. Updates download and install without corruption
4. Fallback works when official URL fails

## Security Considerations

- Download over HTTPS only
- Verify downloaded file is executable
- No execution of downloaded content before verification
- Keep backup of previous AppImage version

## Next Steps

After completion, proceed to Phase 2: Login Fix & Diagnostics
