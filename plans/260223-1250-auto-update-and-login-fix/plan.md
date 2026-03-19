# Claude Desktop AppImage: Auto-Update & Login Fix

## Overview

Improve Claude Desktop AppImage with official Anthropic version checking and fix authentication issues on Linux.

## Problem Statement

1. **Update Function**: Currently checks 3rd-party GitHub repo (`aaddrick/claude-desktop-debian`) which may lag behind official releases
2. **Login Issues**: OAuth token persistence fails on Linux, users must re-authenticate frequently

## Research Summary

### Update Function
- Official URL: `https://downloads.claude.ai/releases/win32/{arch}/{version}/Claude-{hash}.exe`
- No public API for version discovery
- Redirect URL can be captured via HEAD request or browser automation
- Best approach: Hybrid (URL derivation + fallback)

### Login Issues
- Known upstream bug #5767: OAuth token persistence fails on Linux
- Tokens stored in `~/.config/Claude/config.json` (plaintext)
- `--no-sandbox` required for AppImage but reduces security
- Token expiration after 24-48h of inactivity

## Phases

| Phase | Description | Status | Est. Time |
|-------|-------------|--------|-----------|
| 1 | [Auto-Update Function](./phase-01-auto-update-function.md) | Pending | 2h |
| 2 | [Login Fix & Diagnostics](./phase-02-login-fix.md) | Pending | 1h |

## Success Criteria

1. Launcher checks official Anthropic downloads for latest version
2. Auto-downloads and installs updates when available
3. Login diagnostics tool identifies common issues
4. Token refresh workaround prevents frequent re-auth

## Dependencies

- `curl`, `jq` (already required)
- Optional: `python3` for advanced URL resolution

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Anthropic changes URL structure | Update breaks | Fallback to GitHub repo |
| Token fix doesn't persist | User frustration | Clear documentation + API key option |
| Network issues during update | Partial download | Atomic download with temp file |
