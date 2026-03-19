#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Check official Anthropic downloads for latest Claude Desktop version
# Uses the Squirrel/Electron RELEASES endpoint (no Cloudflare protection)

RELEASES_URL="https://downloads.claude.ai/releases/win32/arm64/RELEASES"
CACHE_FILE="$HOME/.cache/claude-desktop-version-cache"
CACHE_TTL=86400  # 24 hours in seconds

# Get cached version if still valid
get_cached_version() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    local cache_time
    cache_time=$(head -1 "$CACHE_FILE" 2>/dev/null)
    local current_time
    current_time=$(date +%s)

    if [ -z "$cache_time" ] || ! [[ $cache_time =~ ^[0-9]+$ ]] || [ $((current_time - cache_time)) -ge $CACHE_TTL ]; then
        return 1
    fi

    # Return cached version (second line)
    sed -n '2p' "$CACHE_FILE"
    return 0
}

# Save version to cache
save_to_cache() {
    local version="$1"
    mkdir -p "$(dirname "$CACHE_FILE")"
    printf '%s\n%s\n' "$(date +%s)" "$version" > "$CACHE_FILE"
}

# Check official Anthropic RELEASES endpoint for latest version
check_official_version() {
    local releases_content
    releases_content=$(curl -sf --connect-timeout 5 --max-time 10 "$RELEASES_URL" 2>/dev/null)

    if [ -z "$releases_content" ]; then
        return 1
    fi

    # Parse version from last line: SHA AnthropicClaude-X.Y.Z-full.nupkg SIZE
    local version
    version=$(echo "$releases_content" | tail -1 | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+')

    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi

    return 1
}

# Fallback: check GitHub releases
check_github_version() {
    local github_api="https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest"

    if ! command -v jq &>/dev/null; then
        return 1
    fi

    local release_info
    release_info=$(curl -sf --connect-timeout 5 --max-time 10 "$github_api" 2>/dev/null)

    if [ -z "$release_info" ]; then
        return 1
    fi

    # Extract Claude Desktop version from asset name: claude-desktop-X.Y.Z-...
    local version
    version=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("arm64.AppImage") and (contains(".zsync") | not)) | .name' 2>/dev/null | head -1 | grep -oP 'claude-desktop-\K[0-9]+\.[0-9]+\.[0-9]+')

    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi

    return 1
}

# Get GitHub download URL for a specific version
get_github_download_url() {
    local github_api="https://api.github.com/repos/aaddrick/claude-desktop-debian/releases/latest"

    if ! command -v jq &>/dev/null; then
        return 1
    fi

    local release_info
    release_info=$(curl -sf --connect-timeout 5 --max-time 10 "$github_api" 2>/dev/null)

    if [ -z "$release_info" ]; then
        return 1
    fi

    local url
    url=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("arm64.AppImage") and (contains(".zsync") | not)) | .browser_download_url' 2>/dev/null | head -1)

    if [ -n "$url" ]; then
        echo "$url"
        return 0
    fi

    return 1
}

# Main: get latest version (cached -> official -> github)
get_latest_version() {
    # Try cache first
    local version
    version=$(get_cached_version)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi

    # Try official Anthropic endpoint
    version=$(check_official_version)
    if [ -n "$version" ]; then
        save_to_cache "$version"
        echo "$version"
        return 0
    fi

    # Fallback to GitHub
    version=$(check_github_version)
    if [ -n "$version" ]; then
        save_to_cache "$version"
        echo "$version"
        return 0
    fi

    return 1
}

# Get latest download URL for AppImage (GitHub releases only)
# Note: RELEASES endpoint provides nupkg URLs which are not directly usable as AppImages.
# Only GitHub has pre-built AppImage assets.
get_latest_download_url() {
    local url
    url=$(get_github_download_url)
    if [ -n "$url" ]; then
        echo "$url"
        return 0
    fi

    return 1
}

# If run directly, print latest version
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    version=$(get_latest_version)
    if [ -n "$version" ]; then
        echo "$version"
    else
        echo "Failed to determine latest version" >&2
        exit 1
    fi
fi
