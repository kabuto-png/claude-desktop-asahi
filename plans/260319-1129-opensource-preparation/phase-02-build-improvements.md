# Phase 2: Build Improvements

## Context
- Parent: [plan.md](plan.md)
- Depends on: [Phase 1](phase-01-license-and-cleanup.md)
- Docs: [system-architecture](../../docs/system-architecture.md)

## Overview
- **Date:** 2026-03-19
- **Priority:** P1
- **Status:** pending
- **Effort:** 1h

Replace hardcoded download URL with dynamic detection. Clean up redundant root-level docs.

## Key Insights
- `check-official-version.sh` already has RELEASES endpoint logic + caching
- Need to add URL construction (not just version detection) from RELEASES data
- RELEASES format: `SHA AnthropicClaude-X.Y.Z-full.nupkg SIZE`
- Download URL pattern: `https://downloads.claude.ai/releases/win32/arm64/{version}/Claude-{hash}.exe`
- 4 root-level docs are redundant — content already in docs/ directory

## Requirements

### Functional
- Build scripts auto-detect latest Claude Desktop download URL
- `--claude-download-url` CLI flag overrides auto-detection
- Clear error if auto-detect fails with instructions

### Non-Functional
- No additional dependencies (use curl already required)
- Cache version/URL to avoid repeated API calls
- Backward compatible CLI interface

## Related Code Files

### Files to MODIFY
- `build-appimage.sh` — replace hardcoded `CLAUDE_DOWNLOAD_URL` default
- `fedora_asahi_build_script.sh` — same, replace hardcoded URL
- `check-official-version.sh` — add `get_download_url()` function for official endpoint
- `README.md` — remove references to redundant root docs

### Files to DELETE
- `complete_usage_guide.md` — content in docs/
- `claude_appimage_documentation.md` — content in docs/
- `PROJECT_STRUCTURE.md` — content in docs/codebase-summary.md
- `VERSION_DETECTION.md` — content in docs/system-architecture.md

## Architecture

### Auto-Detect Flow
```
build-appimage.sh
  ├─ CLI arg --claude-download-url provided?
  │  └─ Yes → use provided URL
  │  └─ No → call get_latest_download_url()
  │     ├─ Source check-official-version.sh
  │     ├─ Get version from RELEASES endpoint
  │     ├─ Construct download URL from version
  │     ├─ Verify URL responds (HEAD request)
  │     └─ Return URL or error
  └─ Continue build with resolved URL
```

### URL Construction Strategy
The RELEASES endpoint gives us version. Download URL pattern:
```
https://downloads.claude.ai/releases/win32/arm64/{version}/Claude-{hash}.exe
```
Problem: hash isn't in RELEASES. Two approaches:
1. **Parse nupkg URL from RELEASES** — the full line has the nupkg filename
2. **Use redirect** — `https://downloads.claude.ai/releases/win32/arm64/latest` may redirect

**Recommended:** Try the redirect approach first. If that fails, parse RELEASES for nupkg URL and download that instead (build scripts already handle nupkg extraction).

## Implementation Steps

1. **Add download URL detection to check-official-version.sh**
   ```bash
   get_latest_download_url() {
     # Try redirect-based URL
     local url="https://downloads.claude.ai/releases/win32/arm64/latest"
     local final_url=$(curl -Ls -o /dev/null -w '%{url_effective}' "$url" 2>/dev/null)
     if [ -n "$final_url" ] && [ "$final_url" != "$url" ]; then
       echo "$final_url"; return 0
     fi
     # Fallback: construct from RELEASES
     local releases=$(curl -sf "$RELEASES_URL" 2>/dev/null)
     local nupkg=$(echo "$releases" | tail -1 | awk '{print $2}')
     local version=$(echo "$nupkg" | grep -oP 'AnthropicClaude-\K[0-9.]+')
     # Return nupkg download URL
     echo "https://downloads.claude.ai/releases/win32/arm64/${version}/${nupkg}"
     return 0
   }
   ```

2. **Update build-appimage.sh**
   - Change default: `CLAUDE_DOWNLOAD_URL=""` (empty = auto-detect)
   - Before build: if URL empty, call auto-detect
   - If auto-detect fails and no override: error with instructions

3. **Update fedora_asahi_build_script.sh**
   - Same pattern as build-appimage.sh
   - Source check-official-version.sh for shared logic

4. **Delete redundant root docs**
   - `rm complete_usage_guide.md claude_appimage_documentation.md PROJECT_STRUCTURE.md VERSION_DETECTION.md`

5. **Update README.md cross-references**
   - Point troubleshooting links to docs/ directory
   - Remove links to deleted files

## Todo List
- [ ] Add `get_latest_download_url()` to check-official-version.sh
- [ ] Update build-appimage.sh to auto-detect URL
- [ ] Update fedora_asahi_build_script.sh to auto-detect URL
- [ ] Test auto-detection works (curl the RELEASES endpoint)
- [ ] Delete complete_usage_guide.md
- [ ] Delete claude_appimage_documentation.md
- [ ] Delete PROJECT_STRUCTURE.md
- [ ] Delete VERSION_DETECTION.md
- [ ] Update README.md cross-references

## Success Criteria
- `./build-appimage.sh` works without hardcoded URL (auto-detects)
- `./build-appimage.sh --claude-download-url <url>` still works as override
- Clear error message if auto-detect fails
- No redundant docs in root directory
- README links point to docs/ files

## Risk Assessment
| Risk | Impact | Mitigation |
|------|--------|------------|
| RELEASES endpoint changes format | High | Multiple fallback strategies, clear error messages |
| Download URL pattern changes | Medium | Override flag always available |
| Users rely on deleted docs | Low | Content preserved in docs/, README links updated |

## Security Considerations
- Download URLs should use HTTPS only
- Verify downloaded file size (existing sanity check)

## Next Steps
→ Phase 3: OSS Infrastructure (can run in parallel)
