# Phase 2: Fix Login Authentication & Add Diagnostics

## Priority: High
## Status: Pending
## Estimated Time: 1 hour

## Overview

Address OAuth token persistence issues on Linux and provide diagnostic tools for troubleshooting authentication problems.

## Key Insights from Research

1. **Known Bug**: Upstream issue #5767 - OAuth token persistence fails on Linux
2. **Token Location**: `~/.config/Claude/config.json`
3. **Common Issues**:
   - Token cache stale/expired after 24-48h inactivity
   - File permissions too open (0664 vs 0600)
   - No Linux secret store (D-Bus/libsecret not available)
4. **Workarounds**:
   - Clear token cache before launch
   - Use API key instead of OAuth
   - Fix file permissions

## Requirements

### Functional
- [ ] Add auth diagnostics to launcher
- [ ] Auto-fix common permission issues
- [ ] Clear stale token cache on launch
- [ ] Provide fallback to API key authentication
- [ ] Add `--diagnose` flag for troubleshooting

### Non-Functional
- [ ] Diagnostics complete in <5 seconds
- [ ] Non-destructive (backup before changes)
- [ ] Clear error messages for users

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Auth Diagnostic Flow                   │
├─────────────────────────────────────────────────────────┤
│  1. Check config directory exists & permissions         │
│     ↓                                                   │
│  2. Check config.json permissions (should be 0600)      │
│     ↓ wrong → auto-fix                                  │
│  3. Check token cache age                               │
│     ↓ stale (>48h) → clear cache                        │
│  4. Test network connectivity to api.anthropic.com     │
│     ↓ fail → show proxy instructions                    │
│  5. Launch Claude Desktop                               │
└─────────────────────────────────────────────────────────┘
```

## Related Code Files

### Files to Modify
- `claude-fixed-launcher-v2.sh` - Add auth diagnostics

### Files to Create
- `claude-auth-diagnostics.sh` - Standalone diagnostic tool

## Implementation Steps

### Step 1: Create Auth Diagnostics Script

Create `claude-auth-diagnostics.sh`:

```bash
#!/bin/bash
# Claude Desktop Authentication Diagnostics

CONFIG_DIR="$HOME/.config/Claude"
CONFIG_FILE="$CONFIG_DIR/config.json"

diagnose_auth() {
    echo "=== Claude Desktop Auth Diagnostics ==="

    # Check config directory
    if [ ! -d "$CONFIG_DIR" ]; then
        echo "❌ Config directory missing: $CONFIG_DIR"
        echo "   Creating directory..."
        mkdir -p "$CONFIG_DIR"
        chmod 700 "$CONFIG_DIR"
    else
        echo "✓ Config directory exists"
    fi

    # Check directory permissions
    local dir_perms=$(stat -c %a "$CONFIG_DIR" 2>/dev/null)
    if [ "$dir_perms" != "700" ]; then
        echo "⚠️  Config directory permissions: $dir_perms (should be 700)"
        echo "   Fixing permissions..."
        chmod 700 "$CONFIG_DIR"
    else
        echo "✓ Config directory permissions: 700"
    fi

    # Check config file
    if [ -f "$CONFIG_FILE" ]; then
        local file_perms=$(stat -c %a "$CONFIG_FILE" 2>/dev/null)
        if [ "$file_perms" != "600" ]; then
            echo "⚠️  Config file permissions: $file_perms (should be 600)"
            echo "   Fixing permissions..."
            chmod 600 "$CONFIG_FILE"
        else
            echo "✓ Config file permissions: 600"
        fi

        # Check token cache
        if command -v jq &>/dev/null; then
            local token_cache=$(jq -r '.["oauth:tokenCache"] // empty' "$CONFIG_FILE" 2>/dev/null)
            if [ -n "$token_cache" ]; then
                echo "✓ OAuth token cache present"
                # Check if token is expired (JWT exp claim)
                local exp=$(echo "$token_cache" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.exp // empty' 2>/dev/null)
                if [ -n "$exp" ]; then
                    local now=$(date +%s)
                    if [ "$exp" -lt "$now" ]; then
                        echo "⚠️  Token expired! Clearing cache..."
                        clear_token_cache
                    else
                        local remaining=$(( (exp - now) / 3600 ))
                        echo "✓ Token valid for ~${remaining}h"
                    fi
                fi
            else
                echo "ℹ️  No OAuth token cache (login required)"
            fi
        fi
    else
        echo "ℹ️  Config file not found (first launch)"
    fi

    # Test network connectivity
    echo ""
    echo "=== Network Connectivity ==="
    if curl -s --connect-timeout 5 https://api.anthropic.com >/dev/null 2>&1; then
        echo "✓ api.anthropic.com reachable"
    else
        echo "❌ Cannot reach api.anthropic.com"
        echo "   Check your network/proxy settings"
    fi

    if curl -s --connect-timeout 5 https://claude.ai >/dev/null 2>&1; then
        echo "✓ claude.ai reachable"
    else
        echo "❌ Cannot reach claude.ai"
    fi
}

clear_token_cache() {
    if [ -f "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
        local backup="$CONFIG_FILE.backup.$(date +%s)"
        cp "$CONFIG_FILE" "$backup"
        jq 'del(.["oauth:tokenCache"])' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        echo "✓ Token cache cleared (backup: $backup)"
    fi
}

fix_all() {
    echo "=== Auto-fixing common issues ==="

    # Fix permissions
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    [ -f "$CONFIG_FILE" ] && chmod 600 "$CONFIG_FILE"

    # Clear stale token cache
    clear_token_cache

    echo "✓ Fixes applied"
}

case "$1" in
    --fix)
        fix_all
        ;;
    --clear-cache)
        clear_token_cache
        ;;
    *)
        diagnose_auth
        ;;
esac
```

### Step 2: Integrate into Launcher

Add to `claude-fixed-launcher-v2.sh`:

```bash
# Add after cleanup_claude() function

fix_auth_permissions() {
    local CONFIG_DIR="$XDG_CONFIG_HOME/Claude"
    local CONFIG_FILE="$CONFIG_DIR/config.json"

    # Ensure proper permissions
    [ -d "$CONFIG_DIR" ] && chmod 700 "$CONFIG_DIR"
    [ -f "$CONFIG_FILE" ] && chmod 600 "$CONFIG_FILE"
}

clear_stale_token_cache() {
    local CONFIG_FILE="$XDG_CONFIG_HOME/Claude/config.json"

    if [ -f "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
        # Check if file was modified more than 48h ago
        local file_age=$(( $(date +%s) - $(stat -c %Y "$CONFIG_FILE") ))
        if [ $file_age -gt 172800 ]; then  # 48 hours
            log_info "Clearing stale auth token cache..."
            jq 'del(.["oauth:tokenCache"])' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" 2>/dev/null
            mv "$CONFIG_FILE.tmp" "$CONFIG_FILE" 2>/dev/null
            chmod 600 "$CONFIG_FILE"
        fi
    fi
}
```

### Step 3: Add --diagnose Flag

Add command-line argument handling:

```bash
# At start of main()
if [ "$1" = "--diagnose" ]; then
    if [ -f "$APPIMAGE_DIR/claude-auth-diagnostics.sh" ]; then
        bash "$APPIMAGE_DIR/claude-auth-diagnostics.sh"
    else
        # Inline diagnostics
        diagnose_auth_inline
    fi
    exit 0
fi
```

## Todo List

- [ ] Create `claude-auth-diagnostics.sh` script
- [ ] Add `fix_auth_permissions()` to launcher
- [ ] Add `clear_stale_token_cache()` to launcher
- [ ] Add `--diagnose` flag support
- [ ] Test on fresh install (no config)
- [ ] Test with expired token
- [ ] Test with wrong permissions
- [ ] Update README with troubleshooting section

## Success Criteria

1. `./claude-auth-diagnostics.sh` shows all auth status
2. `./claude-fixed-launcher-v2.sh --diagnose` runs diagnostics
3. Permission issues auto-fixed on launch
4. Stale token cache cleared automatically
5. Clear error messages guide users to solutions

## Security Considerations

- Backup config before modifications
- Use secure permissions (700/600)
- Don't log token contents
- Validate JSON before parsing

## API Key Alternative

If OAuth continues to fail, users can use API key:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
./claude-fixed-launcher-v2.sh
```

Document this in README as fallback option.
