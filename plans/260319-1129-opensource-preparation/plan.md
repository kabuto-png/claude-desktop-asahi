---
title: "Open-Source Preparation"
description: "Prepare claude-desktop-to-appimage for public open-source release"
status: complete
priority: P1
effort: 3h
branch: main
tags: [opensource, cleanup, license, ci]
created: 2026-03-19
---

# Open-Source Preparation Plan

## Context
- Brainstorm: [brainstorm report](../reports/brainstorm-260319-1129-opensource-preparation.md)
- Upstream projects all use Apache-2.0
- Project has personal paths, wrong license, missing OSS infrastructure

## Phases

| # | Phase | Status | Effort | Description |
|---|-------|--------|--------|-------------|
| 1 | [License & Cleanup](phase-01-license-and-cleanup.md) | complete | 1h | License swap, remove personal files, fix hardcoded paths |
| 2 | [Build Improvements](phase-02-build-improvements.md) | complete | 1h | Auto-detect download URL, clean up redundant docs |
| 3 | [OSS Infrastructure](phase-03-oss-infrastructure.md) | complete | 1h | CONTRIBUTING.md, GitHub templates, ShellCheck CI, SPDX headers |

## Dependencies
- Phase 1 must complete first (license needed before SPDX headers)
- Phase 2 and 3 can run in parallel after Phase 1

## Success Criteria
- No personal paths or data in any file
- Apache-2.0 LICENSE file present
- Build works from clean clone without manual edits
- All upstream projects properly credited
- GitHub repo has issue templates and CI
- shellcheck passes on all .sh files (or documented exceptions)
