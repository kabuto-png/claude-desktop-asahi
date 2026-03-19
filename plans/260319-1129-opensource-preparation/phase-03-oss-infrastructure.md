# Phase 3: OSS Infrastructure

## Context
- Parent: [plan.md](plan.md)
- Depends on: [Phase 1](phase-01-license-and-cleanup.md) (needs LICENSE for SPDX headers)
- Can run parallel with: [Phase 2](phase-02-build-improvements.md)

## Overview
- **Date:** 2026-03-19
- **Priority:** P2
- **Status:** pending
- **Effort:** 1h

Add standard open-source project infrastructure: contributing guide, issue/PR templates, CI, SPDX headers.

## Requirements

### Functional
- CONTRIBUTING.md with development setup and PR process
- GitHub issue templates for bugs and feature requests
- PR template with checklist
- ShellCheck CI on push/PR
- SPDX license headers in all .sh files

### Non-Functional
- Templates should be concise and actionable
- CI should not block on warnings, only errors

## Related Code Files

### Files to CREATE
- `CONTRIBUTING.md` (root — standard OSS location)
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/lint.yml`

### Files to MODIFY (SPDX headers)
All .sh files in root (~20 files). Add as second line after shebang:
```bash
#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
```

## Implementation Steps

### 1. Create CONTRIBUTING.md
Content outline:
- How to report bugs (use issue template)
- Development setup (clone, chmod +x, dependencies)
- Testing (build on target arch, test AppImage launch)
- PR process (fork, branch, shellcheck, PR template)
- Code style (reference docs/code-standards.md)
- Credits to upstream projects

### 2. Create bug report template
`.github/ISSUE_TEMPLATE/bug_report.md` with frontmatter:
```yaml
---
name: Bug Report
about: Report a build or runtime issue
labels: bug
---
```
Sections: Description, Steps to Reproduce, Expected/Actual behavior, Environment (OS, arch, Claude version, Electron version)

### 3. Create feature request template
`.github/ISSUE_TEMPLATE/feature_request.md`:
```yaml
---
name: Feature Request
about: Suggest an improvement
labels: enhancement
---
```
Sections: Problem, Proposed Solution, Alternatives Considered

### 4. Create PR template
`.github/PULL_REQUEST_TEMPLATE.md`:
- Summary of changes
- Checklist: shellcheck passes, tested on target arch, docs updated, no personal paths

### 5. Create ShellCheck CI workflow
`.github/workflows/lint.yml`:
```yaml
name: ShellCheck
on: [push, pull_request]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install ShellCheck
        run: sudo apt-get install -y shellcheck
      - name: Run ShellCheck
        run: shellcheck -s bash -S error *.sh
```
Notes:
- `-S error` = only fail on errors, not warnings/info
- Can add `-e SC1090,SC1091` to exclude source-related warnings if needed

### 6. Add SPDX headers to all .sh files
For each .sh file in root:
- Insert `# SPDX-License-Identifier: Apache-2.0` after shebang line
- If file has no shebang, add both

Files (~20):
```
add_persistence_simple.sh, build-appimage.sh, check-official-version.sh,
check_appimage_version.sh, check_latest_version.sh, claude-auth-diagnostics.sh,
claude-fixed-launcher-v2.sh, claude-kill.sh, claude-launcher-no-update.sh,
claude-status.sh, cleanup-claude.sh, debug-claude-launcher.sh,
fedora_asahi_build_script.sh, find_latest_claude.sh, get_actual_version.sh,
investigate_version_sources.sh, manual_appimage_builder.sh
```

## Todo List
- [ ] Create CONTRIBUTING.md
- [ ] Create .github/ISSUE_TEMPLATE/bug_report.md
- [ ] Create .github/ISSUE_TEMPLATE/feature_request.md
- [ ] Create .github/PULL_REQUEST_TEMPLATE.md
- [ ] Create .github/workflows/lint.yml
- [ ] Add SPDX header to all .sh files (~20 files)
- [ ] Run shellcheck locally to verify CI will pass
- [ ] Fix any shellcheck errors found

## Success Criteria
- CONTRIBUTING.md exists and is linked from README
- Issue templates appear when creating new GitHub issue
- PR template auto-populates on new PR
- `shellcheck -S error *.sh` passes
- All .sh files have SPDX header

## Risk Assessment
| Risk | Impact | Mitigation |
|------|--------|------------|
| ShellCheck finds many errors | Medium | Use `-S error` to only fail on real errors; fix incrementally |
| Templates too verbose | Low | Keep concise, iterate based on community feedback |

## Security Considerations
- CI workflow uses pinned action versions (checkout@v4)
- No secrets needed for shellcheck

## Next Steps
→ Final review of all changes
→ Commit and push
→ Verify GitHub renders templates correctly
