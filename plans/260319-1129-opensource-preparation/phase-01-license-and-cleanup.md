# Phase 1: License & Cleanup

## Context
- Parent: [plan.md](plan.md)
- Brainstorm: [brainstorm report](../reports/brainstorm-260319-1129-opensource-preparation.md)
- Docs: [codebase-summary](../../docs/codebase-summary.md)

## Overview
- **Date:** 2026-03-19
- **Priority:** P0 — Critical (blocks all other phases)
- **Status:** pending
- **Effort:** 1h

Remove all personal data and set correct license before public release.

## Key Insights
- All 3 upstream repos use Apache-2.0
- LICENSE-MIT exists but wrong license
- 4 files have hardcoded `/home/longne` paths
- 4 personal note files have no value for public consumers

## Requirements

### Functional
- Replace MIT license with Apache-2.0
- Remove all personal identifying paths
- Remove personal development notes

### Non-Functional
- No breaking changes to CLI interface
- Scripts must work from any directory after clone

## Related Code Files

### Files to DELETE
- `LICENSE-MIT` → replaced by `LICENSE`
- `BUILD_SUCCESS_REPORT.md` — personal build log
- `CHANGES_SUMMARY.md` — personal change notes
- `WHAT_I_LEARNED.md` — learning notes (content in docs/system-architecture.md)
- `CLAUDE_CODE_PATCHES.md` — patch docs (content in docs/system-architecture.md)

### Files to MODIFY
- `claude-fixed-launcher-v2.sh` line 8: `APPIMAGE_DIR="/home/longne/syncthings/Documents/claude-desktop-to-appimage"` → `APPIMAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- `fedora_asahi_build_script.sh` line 180: `export PATH="/home/longne/.npm-global/bin:$PATH"` → `export PATH="$(npm config get prefix 2>/dev/null)/bin:$PATH"`
- `claude-launcher-no-update.sh`: hardcoded AppImage path → auto-detect using `find` pattern
- `debug-claude-launcher.sh`: hardcoded AppImage path → auto-detect using `find` pattern
- `README.md`: update license badge from MIT to Apache-2.0

### Files to CREATE
- `LICENSE` — Apache-2.0 full text

## Implementation Steps

1. **Create Apache-2.0 LICENSE file**
   - Write standard Apache-2.0 license text
   - Set copyright to "2025 Contributors"

2. **Delete LICENSE-MIT**

3. **Delete personal files**
   - `rm BUILD_SUCCESS_REPORT.md CHANGES_SUMMARY.md WHAT_I_LEARNED.md CLAUDE_CODE_PATCHES.md`

4. **Fix claude-fixed-launcher-v2.sh**
   - Line 8: Replace hardcoded APPIMAGE_DIR with dynamic SCRIPT_DIR detection
   - Verify all other paths in file are relative or use variables

5. **Fix fedora_asahi_build_script.sh**
   - Line 180: Replace hardcoded npm path with dynamic detection
   - Pattern: `export PATH="$(npm config get prefix 2>/dev/null)/bin:$PATH"`

6. **Fix claude-launcher-no-update.sh**
   - Replace hardcoded APPIMAGE_PATH with auto-detection
   - Reuse find pattern from claude-fixed-launcher-v2.sh

7. **Fix debug-claude-launcher.sh**
   - Replace hardcoded APPIMAGE_PATH with auto-detection
   - Same pattern as above

8. **Update README.md**
   - Change license badge from MIT to Apache-2.0
   - Change license section references
   - Update "LICENSE-MIT" references to "LICENSE"

9. **Verify no remaining personal paths**
   - Run: `grep -rn "/home/longne" *.sh *.md`
   - Should return 0 results

## Todo List
- [ ] Create LICENSE (Apache-2.0)
- [ ] Delete LICENSE-MIT
- [ ] Delete BUILD_SUCCESS_REPORT.md
- [ ] Delete CHANGES_SUMMARY.md
- [ ] Delete WHAT_I_LEARNED.md
- [ ] Delete CLAUDE_CODE_PATCHES.md
- [ ] Fix hardcoded path in claude-fixed-launcher-v2.sh
- [ ] Fix hardcoded path in fedora_asahi_build_script.sh
- [ ] Fix hardcoded path in claude-launcher-no-update.sh
- [ ] Fix hardcoded path in debug-claude-launcher.sh
- [ ] Update README.md license references
- [ ] Verify grep returns no personal paths

## Success Criteria
- `grep -rn "/home/longne" *.sh *.md` returns empty
- `LICENSE` file exists with Apache-2.0 text
- `LICENSE-MIT` no longer exists
- Personal note files deleted
- README references Apache-2.0

## Risk Assessment
| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking launcher scripts | High | Test SCRIPT_DIR detection works when symlinked |
| npm path detection fails | Medium | Fallback: check common paths (/usr/local/bin, ~/.npm-global/bin) |

## Security Considerations
- No credentials in any file
- No API keys or tokens

## Next Steps
→ Phase 2: Build Improvements (auto-detect download URL)
→ Phase 3: OSS Infrastructure (can start in parallel)
