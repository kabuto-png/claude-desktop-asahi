# Brainstorm: Open-Sourcing Claude Desktop AppImage Builder

**Date:** 2026-03-19
**Status:** Agreed - ready for implementation plan

## Problem Statement

Project needs preparation for open-source release. Currently contains personal paths, personal notes, wrong license reference, hardcoded download URLs, and lacks standard OSS infrastructure.

## Key Findings

### License Situation
- All 3 upstream projects use **Apache-2.0** (christian-korneck, aaddrick, bsneed)
- README claimed MIT, `LICENSE-MIT` file exists → must replace with Apache-2.0
- Apache-2.0 is compatible and consistent with upstream chain

### Legal Considerations
- Project patches Anthropic's proprietary app (extracts from Windows installer, patches JS)
- Anthropic hasn't issued takedowns against similar projects (aaddrick, christian-korneck still active)
- Disclaimer in README already states unofficial nature
- We don't redistribute Anthropic's code — script downloads it at build time
- **Risk level: Low-Medium** — same pattern as upstream projects that have been public for months

### Cleanup Required

**Personal files to remove:**
- `BUILD_SUCCESS_REPORT.md` - build log, no value for others
- `CHANGES_SUMMARY.md` - personal change notes
- `WHAT_I_LEARNED.md` - learning notes (content already captured in docs/)
- `CLAUDE_CODE_PATCHES.md` - patch docs (already in docs/system-architecture.md)

**Hardcoded paths to fix:**
- `claude-fixed-launcher-v2.sh:8` — `APPIMAGE_DIR="/home/longne/syncthings/..."`
- `fedora_asahi_build_script.sh:180` — `export PATH="/home/longne/.npm-global/bin:$PATH"`
- `claude-launcher-no-update.sh` — hardcoded AppImage path
- `debug-claude-launcher.sh` — hardcoded AppImage path

**Outdated references:**
- Version numbers (0.9.3, 0.14.10) in various places
- `LICENSE-MIT` file → replace with `LICENSE` (Apache-2.0)

### Download URL Strategy
- Replace hardcoded URL with dynamic detection via RELEASES endpoint
- `check-official-version.sh` already has the logic
- Build script should auto-detect, with `--claude-download-url` as override
- Fallback chain: RELEASES endpoint → user-provided URL → error with instructions

## Agreed Approach

### 1. License (Apache-2.0)
- Delete `LICENSE-MIT`
- Create `LICENSE` with Apache-2.0 text
- Update README license badge and references
- Add SPDX headers to shell scripts

### 2. Full Cleanup
- Delete personal files (BUILD_SUCCESS_REPORT.md, CHANGES_SUMMARY.md, WHAT_I_LEARNED.md, CLAUDE_CODE_PATCHES.md)
- Fix all hardcoded `/home/longne` paths → use `$HOME`, `$(pwd)`, `$SCRIPT_DIR`
- Remove outdated version references
- Clean up redundant docs (complete_usage_guide.md, claude_appimage_documentation.md, PROJECT_STRUCTURE.md, VERSION_DETECTION.md) — content now in docs/

### 3. GitHub OSS Infrastructure
- `CONTRIBUTING.md` — how to contribute, test, submit PRs
- `.github/ISSUE_TEMPLATE/bug_report.md` — structured bug reports
- `.github/ISSUE_TEMPLATE/feature_request.md` — feature requests
- `.github/workflows/lint.yml` — ShellCheck CI for all .sh files
- `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist

### 4. Auto-Detect Download URL
- Modify `build-appimage.sh` and `fedora_asahi_build_script.sh`
- Use `check-official-version.sh` logic to get latest download URL
- Keep `--claude-download-url` as override
- Clear error message if auto-detect fails

## Implementation Priority

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | License swap (MIT → Apache-2.0) | Low | Critical |
| 2 | Remove personal files | Low | Critical |
| 3 | Fix hardcoded paths | Medium | Critical |
| 4 | Auto-detect download URL | Medium | High |
| 5 | Clean up redundant root docs | Low | Medium |
| 6 | CONTRIBUTING.md | Low | Medium |
| 7 | Issue/PR templates | Low | Medium |
| 8 | ShellCheck CI | Medium | Medium |
| 9 | SPDX headers in scripts | Low | Low |

## Risks

| Risk | Mitigation |
|------|------------|
| Anthropic DMCA/takedown | Disclaimer, don't redistribute code, download at build time (same as upstream) |
| RELEASES endpoint changes | Fallback to user-provided URL, clear error messages |
| Breaking existing users' setups | Document migration, keep CLI args backward-compatible |

## Success Criteria
- [ ] No personal paths or data in any file
- [ ] Apache-2.0 LICENSE file present
- [ ] `shellcheck` passes on all .sh files (or documented exceptions)
- [ ] Build works from clean clone without manual edits
- [ ] All upstream projects properly credited
- [ ] GitHub repo has issue templates and CI

## Unresolved Questions
1. GitHub username/org for the repo URL in README? (currently placeholder)
2. Should `shfile/` directory scripts be included or removed? (referenced in PROJECT_STRUCTURE.md but may not exist)
