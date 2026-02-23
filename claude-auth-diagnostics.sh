#!/bin/bash
# Claude Desktop Authentication Diagnostics
# Checks auth config, permissions, token cache, and network connectivity

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Claude"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }
info() { echo -e "  ${CYAN}[INFO]${NC} $1"; }

diagnose_auth() {
    echo "============================================"
    echo " Claude Desktop Auth Diagnostics"
    echo "============================================"
    echo ""

    local issues=0

    # --- Config Directory ---
    echo "--- Config Directory ---"
    if [ ! -d "$CONFIG_DIR" ]; then
        fail "Config directory missing: $CONFIG_DIR"
        info "Will be created on first launch"
        issues=$((issues + 1))
    else
        pass "Config directory exists: $CONFIG_DIR"

        local dir_perms
        dir_perms=$(stat -c %a "$CONFIG_DIR" 2>/dev/null)
        if [ "$dir_perms" != "700" ]; then
            warn "Directory permissions: $dir_perms (recommended: 700)"
            issues=$((issues + 1))
        else
            pass "Directory permissions: 700"
        fi
    fi
    echo ""

    # --- Config File ---
    echo "--- Config File ---"
    if [ -f "$CONFIG_FILE" ]; then
        pass "Config file exists: $CONFIG_FILE"

        local file_perms
        file_perms=$(stat -c %a "$CONFIG_FILE" 2>/dev/null)
        if [ "$file_perms" != "600" ]; then
            warn "File permissions: $file_perms (recommended: 600)"
            issues=$((issues + 1))
        else
            pass "File permissions: 600"
        fi

        # Validate JSON
        if command -v jq &>/dev/null; then
            if jq empty "$CONFIG_FILE" 2>/dev/null; then
                pass "Config file is valid JSON"
            else
                fail "Config file is not valid JSON"
                issues=$((issues + 1))
            fi
        else
            info "jq not installed - skipping JSON validation"
        fi
    else
        info "Config file not found (normal for first launch)"
    fi
    echo ""

    # --- OAuth Token Cache ---
    echo "--- OAuth Token Cache ---"
    if [ -f "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
        local has_token
        has_token=$(jq -r 'to_entries[] | select(.key | startswith("oauth")) | .key' "$CONFIG_FILE" 2>/dev/null)

        if [ -n "$has_token" ]; then
            pass "OAuth token entries found"

            # Check config file age as proxy for token staleness
            local file_mod
            file_mod=$(stat -c %Y "$CONFIG_FILE" 2>/dev/null)
            if [ -n "$file_mod" ]; then
                local now
                now=$(date +%s)
                local age_hours=$(( (now - file_mod) / 3600 ))
                if [ "$age_hours" -gt 48 ]; then
                    warn "Config file last modified ${age_hours}h ago - token may be stale"
                    issues=$((issues + 1))
                else
                    pass "Config file recently modified (${age_hours}h ago)"
                fi
            fi
        else
            info "No OAuth token cache (login required on next launch)"
        fi
    elif ! command -v jq &>/dev/null; then
        info "jq not installed - skipping token cache check"
    else
        info "No config file to check"
    fi
    echo ""

    # --- Network Connectivity ---
    echo "--- Network Connectivity ---"
    if command -v curl &>/dev/null; then
        if curl -s --connect-timeout 5 -o /dev/null -w "" https://api.anthropic.com 2>/dev/null; then
            pass "api.anthropic.com reachable"
        else
            fail "Cannot reach api.anthropic.com"
            info "Check your network connection or proxy settings"
            issues=$((issues + 1))
        fi

        if curl -s --connect-timeout 5 -o /dev/null -w "" https://claude.ai 2>/dev/null; then
            pass "claude.ai reachable"
        else
            fail "Cannot reach claude.ai"
            issues=$((issues + 1))
        fi
    else
        info "curl not installed - skipping network checks"
    fi
    echo ""

    # --- D-Bus / Secret Store ---
    echo "--- Secret Store (D-Bus) ---"
    if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
        pass "D-Bus session bus available"
    else
        warn "D-Bus session bus not detected"
        info "OAuth tokens may not persist between sessions"
        issues=$((issues + 1))
    fi
    echo ""

    # --- Summary ---
    echo "============================================"
    if [ "$issues" -eq 0 ]; then
        echo -e " ${GREEN}All checks passed${NC}"
    else
        echo -e " ${YELLOW}Found $issues issue(s)${NC}"
        echo " Run with --fix to auto-fix common issues"
        echo " Run with --clear-cache to clear stale tokens"
    fi
    echo "============================================"
}

clear_token_cache() {
    if [ ! -f "$CONFIG_FILE" ]; then
        info "No config file found - nothing to clear"
        return 0
    fi

    if ! command -v jq &>/dev/null; then
        fail "jq is required to clear token cache"
        return 1
    fi

    # Validate JSON first
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        fail "Config file is not valid JSON - cannot safely modify"
        return 1
    fi

    # Check if there are any oauth entries
    local oauth_keys
    oauth_keys=$(jq -r 'to_entries[] | select(.key | startswith("oauth")) | .key' "$CONFIG_FILE" 2>/dev/null)
    if [ -z "$oauth_keys" ]; then
        info "No OAuth token cache entries found"
        return 0
    fi

    # Backup before modifying
    local backup="$CONFIG_FILE.backup.$(date +%s)"
    cp "$CONFIG_FILE" "$backup"

    # Remove all oauth-related keys
    jq 'with_entries(select(.key | startswith("oauth") | not))' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" 2>/dev/null
    if [ $? -eq 0 ] && [ -s "$CONFIG_FILE.tmp" ]; then
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        pass "Token cache cleared (backup: $backup)"
    else
        rm -f "$CONFIG_FILE.tmp"
        fail "Failed to clear token cache - backup preserved at $backup"
        return 1
    fi
}

fix_all() {
    echo "============================================"
    echo " Claude Desktop Auth Auto-Fix"
    echo "============================================"
    echo ""

    # Fix config directory
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        chmod 700 "$CONFIG_DIR"
        pass "Created config directory with correct permissions"
    else
        chmod 700 "$CONFIG_DIR"
        pass "Fixed config directory permissions to 700"
    fi

    # Fix config file permissions
    if [ -f "$CONFIG_FILE" ]; then
        chmod 600 "$CONFIG_FILE"
        pass "Fixed config file permissions to 600"
    fi

    # Clear stale token cache
    if [ -f "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
        local file_mod
        file_mod=$(stat -c %Y "$CONFIG_FILE" 2>/dev/null)
        local now
        now=$(date +%s)
        local age_hours=$(( (now - file_mod) / 3600 ))

        if [ "$age_hours" -gt 48 ]; then
            info "Config file is ${age_hours}h old - clearing stale token cache..."
            clear_token_cache
        else
            pass "Token cache is recent (${age_hours}h) - keeping"
        fi
    fi

    echo ""
    echo "============================================"
    echo -e " ${GREEN}Fixes applied${NC}"
    echo "============================================"
}

# --- Main ---
case "${1:-}" in
    --fix)
        fix_all
        ;;
    --clear-cache)
        echo "Clearing OAuth token cache..."
        clear_token_cache
        ;;
    --help|-h)
        echo "Usage: $(basename "$0") [OPTION]"
        echo ""
        echo "Claude Desktop Authentication Diagnostics"
        echo ""
        echo "Options:"
        echo "  (none)         Run diagnostics"
        echo "  --fix          Auto-fix common permission and token issues"
        echo "  --clear-cache  Clear OAuth token cache"
        echo "  --help, -h     Show this help"
        ;;
    *)
        diagnose_auth
        ;;
esac
