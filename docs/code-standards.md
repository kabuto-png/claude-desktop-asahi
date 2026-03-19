# Code Standards & Conventions

## Language & Framework
- **Primary**: Bash shell scripting (POSIX + bash extensions)
- **Secondary**: JSON (package.json config)
- **Assumption**: Linux/Unix environment (sed, awk, grep available)

## File Naming Conventions

### Shell Scripts
- Format: `kebab-case.sh`
- Descriptive purpose: `scripts/launcher/claude-launcher.sh` not `launcher.sh`
- Version suffix if multiple variants: `scripts/launcher/claude-launcher-no-update.sh`
- Avoid single-letter names: `c.sh` ❌, `claude-cli.sh` ✓

### Directory Organization
- Scripts organized by function: `scripts/{builders,launcher,tools,version,legacy}/`
- Each category has focused responsibilities
- Deprecated scripts moved to `scripts/legacy/`

### Configuration
- `package.json` - npm/Node config
- `.gitignore` - Git exclusions
- Documentation: `*.md` files in `docs/` directory

## Script Structure

### Header Block
```bash
#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Claude Desktop AppImage Project
#
# Description: Brief explanation of what this script does
# Usage: ./script-name.sh [OPTIONS]
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Build/execution error
#   3 - Missing dependencies

set -e  # Exit on any error
set -u  # Error on undefined variables

# ... script content
```

### Shebang
- Always use `#!/bin/bash` (not sh, not /usr/bin/env bash)
- Ensures script execution in bash, not POSIX sh

### Error Handling
- Use `set -e` to exit on first error
- Use `set -u` to catch undefined variables
- Add trap for cleanup:
  ```bash
  trap 'cleanup_function' EXIT
  ```
- Explicit error messages with context:
  ```bash
  if ! command_here; then
    echo "ERROR: Failed to do X. Check Y and Z." >&2
    exit 1
  fi
  ```

## Variable Naming

### Constants
- ALL_CAPS with underscores
- Declared at top of file
- Example: `APPIMAGE_NAME`, `CLAUDE_CONFIG_DIR`, `VERSION_CACHE_TIME`

### Variables
- lower_case with underscores
- Declare type in comments if not obvious
- Example: `is_fedora_asahi`, `version_latest`, `build_count`

### Prefixes for Clarity
- `is_` for booleans: `is_update_available`, `is_fedora_asahi`
- `get_` for retrieval functions: `get_latest_version()`, `get_hidpi_scale()`
- `check_` for validation: `check_dependencies()`, `check_version_mismatch()`
- `setup_` for initialization: `setup_directories()`, `setup_environment()`

### Path Variables
- Use descriptive names: `APPIMAGE_DIR` not `DIR`
- Always quote expansions: `"$APPIMAGE_DIR"` not $APPIMAGE_DIR
- Use `$HOME` instead of `~` in scripts

## Function Organization

### Function Definition
```bash
function_name() {
    # One-line description
    # Args: $1 = param1, $2 = param2 (optional)
    # Returns: 0 on success, 1 on error
    # Outputs: Description of stdout/stderr

    local result
    # ... implementation
    return 0
}
```

### Function Naming
- lower_case_with_underscores
- Verb-first: `download_appimage()`, `apply_patches()`, `kill_processes()`
- Not: `appimage_download()` or `patches_apply()`

### Function Order
1. Constants and globals
2. Utility functions (helpers)
3. Main functions (high-level operations)
4. Main script flow (execution)

### Single Responsibility
- One function = one clear purpose
- If function is >50 lines, consider splitting
- Avoid nested function definitions

## Error Handling Patterns

### Exit Codes
- 0: Success
- 1: General error (missing file, bad input)
- 2: Build/execution error (AppImage build failed)
- 3: Missing dependencies
- 4: Permission denied
- 5: Already running (for process checks)

### Validation Pattern
```bash
if ! [[ $arg =~ ^[0-9]+$ ]]; then
    echo "ERROR: Expected number, got '$arg'" >&2
    return 1
fi
```

### Command Failure Pattern
```bash
if ! command_here; then
    echo "ERROR: Command failed. Details: $?" >&2
    return 1
fi
```

### File Operation Pattern
```bash
if [[ ! -f "$file_path" ]]; then
    echo "ERROR: File not found: $file_path" >&2
    return 1
fi

if [[ ! -r "$file_path" ]]; then
    echo "ERROR: Permission denied reading: $file_path" >&2
    return 1
fi
```

## Conditionals & Tests

### Preferred Style
- Use `[[` instead of `[` (bash extension, more readable)
- Use `=~` for regex matching
- Quote variables: `[[ "$var" == "value" ]]`
- Use `-z` for empty string: `[[ -z "$var" ]]`
- Use `-n` for non-empty: `[[ -n "$var" ]]`

### File Tests
```bash
[[ -f $file ]]      # Regular file exists
[[ -d $dir ]]       # Directory exists
[[ -r $file ]]      # Readable
[[ -w $file ]]      # Writable
[[ -x $file ]]      # Executable
[[ -s $file ]]      # File exists and not empty
```

### String Tests
```bash
[[ -z $var ]]       # Empty string
[[ -n $var ]]       # Non-empty string
[[ $var == $val ]]  # String equal
[[ $var =~ regex ]] # Regex match
```

## Loops & Iteration

### For Loops
```bash
for item in "$@"; do
    # Process item
done

for file in ./*.sh; do
    # Process shell files
done

for ((i=0; i<10; i++)); do
    # C-style loop
done
```

### While Loops
```bash
while [[ $count -lt 10 ]]; do
    # Process
    ((count++))
done

while read -r line; do
    # Process line from stdin
done < "$file"
```

## String Manipulation

### Command Substitution
- Use `$()` not backticks
- `version=$(cat version.txt)` ✓
- `version=`cat version.txt`` ❌

### Variable Expansion
- Quote variables: `"$var"` not `$var`
- Use `${var:-default}` for defaults
- Use `${var#prefix}` for prefix removal
- Use `${var%suffix}` for suffix removal

### Multiline Strings
```bash
cat << 'EOF'
This is a multiline string
It can contain special characters
EOF

# Or with variable expansion:
cat << EOF
Version: $version
File: $file
EOF
```

## Comments & Documentation

### Inline Comments
- Comment WHY, not WHAT
- Explain non-obvious logic
- ❌ `i=$((i+1))  # Increment i`
- ✓ `# Skip header line in version file`

### Function Comments
- One-line summary at start
- Document parameters and return values
- Example:
  ```bash
  # Download and extract official Claude Desktop installer
  # Args: $1 = target directory, $2 = (optional) timeout in seconds
  # Returns: 0 on success, 1 if download failed, 2 if extract failed
  function download_installer() {
      # ...
  }
  ```

### Section Comments
```bash
# ==========================================
# Build Phase: Download and Extract
# ==========================================

function download_appimage() {
    # ...
}
```

## Dependency Management

### External Tools
- Document all required tools at top of script
- Check before use:
  ```bash
  if ! command -v curl &> /dev/null; then
      echo "ERROR: curl is required but not installed" >&2
      exit 3
  fi
  ```

### Optional Dependencies
- Document fallback behavior
- Example: Try curl, fall back to wget
  ```bash
  if command -v curl &> /dev/null; then
      curl "$url" -o "$output"
  elif command -v wget &> /dev/null; then
      wget "$url" -O "$output"
  else
      echo "ERROR: curl or wget required" >&2
      exit 3
  fi
  ```

### Version Checks
- Check major version for compatibility:
  ```bash
  fedora_version=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2)
  if [[ $fedora_version -lt 37 ]]; then
      echo "ERROR: Fedora 37+ required, found: $fedora_version" >&2
      exit 1
  fi
  ```

## Logging & Output

### Standard Output (Success)
- Use for normal program output
- User should see informational messages
- Example: `echo "AppImage built: ./claude.AppImage"`

### Standard Error (Messages)
- Use for warnings, errors, diagnostics
- Use `>&2` redirection
- Example: `echo "WARNING: Update available" >&2`

### Log Levels
```bash
# Info (normal operation)
echo "[INFO] Starting build..."

# Warning (potential issue)
echo "[WARNING] Low disk space" >&2

# Error (operation failed)
echo "[ERROR] Build failed" >&2

# Debug (troubleshooting)
if [[ "$DEBUG" == "1" ]]; then
    echo "[DEBUG] Variable value: $var" >&2
fi
```

### User-Friendly Messages
- Be specific about problems
- Suggest remediation
- Example:
  ```bash
  echo "ERROR: appimagetool not found." >&2
  echo "Install with: sudo dnf install appimagetool" >&2
  exit 3
  ```

## Performance Considerations

### Avoid Subshells
- ❌ Inefficient: `version=$(cat "$file")`
- ✓ Better: `mapfile -t version < "$file"`
- ✓ Good if shell builtin available: `IFS=$'\n' read -r version < "$file"`

### Minimize External Commands
- Use bash builtins when possible
- Example: `[[ $var =~ regex ]]` not `echo "$var" | grep regex`

### Caching & Memoization
- Cache version checks (~/.cache/claude-version-cache)
- Cache API responses with TTL
- Avoid repeated network calls

## Security Patterns

### Input Validation
- Validate all user input
- Use whitelist matching:
  ```bash
  if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "ERROR: Invalid version format" >&2
      return 1
  fi
  ```

### Credential Handling
- Never log tokens or passwords
- Mask in debug output:
  ```bash
  # ✓ Safe: Show length, not value
  echo "Token length: ${#token}"

  # ❌ Unsafe: Shows full token
  echo "Token: $token"
  ```

### File Permissions
- Set restrictive permissions on sensitive files:
  ```bash
  touch "$token_file"
  chmod 600 "$token_file"  # Only user can read/write
  ```

### Temporary Files
- Use mktemp instead of hardcoded paths:
  ```bash
  temp_dir=$(mktemp -d)
  trap "rm -rf '$temp_dir'" EXIT
  ```

## Testing Patterns

### Return Code Checking
```bash
if ! function_name arg1 arg2; then
    echo "ERROR: function_name failed with code $?" >&2
    return 1
fi
```

### Output Capture
```bash
output=$(command 2>&1)
if [[ $? -eq 0 ]]; then
    echo "Success: $output"
else
    echo "Failed: $output" >&2
fi
```

### Debugging
- Run with `bash -x script.sh` for trace output
- Add conditional debug logging:
  ```bash
  DEBUG=${DEBUG:-0}
  [[ $DEBUG -eq 1 ]] && echo "[DEBUG] $message" >&2
  ```

## SPDX License Headers

All shell scripts must include Apache-2.0 SPDX header:
```bash
#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 Claude Desktop AppImage Project
```

This identifies the license and copyright for automated tools and ensures compliance.

## CI/CD Standards

- All scripts must pass ShellCheck validation
- Pull requests trigger automated test build
- Release workflow validates checksums and artifacts

## Common Pitfalls to Avoid

1. ❌ Unquoted variables: `$var` → Use `"$var"` except in specific contexts
2. ❌ Hardcoded paths: `/home/user/...` → Use `$HOME` or functions
3. ❌ Ignoring exit codes: `command` → Use `command || return 1`
4. ❌ Empty file tests: `[[ -f $file ]]` → Quote: `[[ -f "$file" ]]`
5. ❌ Using backticks: `` `cmd` `` → Use `$(cmd)` for better nesting
6. ❌ Testing return codes in pipelines: Check last command only
7. ❌ Globbing in quotes: `"$dir"/*.txt` → Use `"$dir"/"*.txt"` or array
8. ❌ Naked `cd`: Always trap EXIT to return to original dir
9. ❌ Global variables everywhere: Use `local` in functions
10. ❌ Assuming tool availability: Always check with `command -v`
11. ❌ Missing SPDX headers: All scripts require Apache-2.0 header
12. ❌ Hardcoding credentials: Never log tokens or passwords in debug output

---

**Last Updated**: 2026-03-19
