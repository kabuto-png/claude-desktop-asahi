#!/bin/bash

# Desktop Commander MCP Installation Script
# This script installs Desktop Commander MCP for Claude Desktop
# Works on macOS, Linux, and Windows (WSL/Git Bash)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Desktop Commander MCP Installer                 ║"
    echo "║        Terminal Commands and File Editing for Claude AI      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Function to get Claude config path
get_claude_config_path() {
    local os=$(detect_os)
    
    case $os in
        "macos")
            echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
            ;;
        "linux")
            echo "$HOME/.config/Claude/claude_desktop_config.json"
            ;;
        "windows")
            echo "$APPDATA/Claude/claude_desktop_config.json"
            ;;
        *)
            print_error "Unsupported operating system: $OSTYPE"
            exit 1
            ;;
    esac
}

# Function to check if Claude Desktop is installed
check_claude_desktop() {
    local os=$(detect_os)
    local claude_installed=false
    
    case $os in
        "macos")
            if [ -d "/Applications/Claude.app" ]; then
                claude_installed=true
            fi
            ;;
        "windows")
            if command -v claude &> /dev/null; then
                claude_installed=true
            fi
            ;;
        "linux")
            if command -v claude &> /dev/null || [ -f "$HOME/.local/share/applications/claude.desktop" ]; then
                claude_installed=true
            fi
            ;;
    esac
    
    if [ "$claude_installed" = false ]; then
        print_warning "Claude Desktop app not detected. Please install it from https://claude.ai/download before proceeding."
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Claude Desktop detected"
    fi
}

# Function to check Node.js version
check_nodejs() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d 'v' -f 2)
        NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d '.' -f 1)

        if [ "$NODE_MAJOR_VERSION" -lt 18 ]; then
            print_error "Detected Node.js v$NODE_VERSION, but v18+ is required"
            return 1
        else
            print_success "Node.js v$NODE_VERSION detected"
            return 0
        fi
    else
        print_warning "Node.js not found"
        return 1
    fi
}

# Function to install Node.js on macOS
install_nodejs_macos() {
    print_info "Installing Node.js v22.14.0 for macOS..."
    
    mkdir -p /tmp/nodejs-install
    curl -fsSL -o /tmp/nodejs-install/node-v22.14.0.pkg https://nodejs.org/dist/v22.14.0/node-v22.14.0.pkg
    
    print_info "Installing Node.js (requires sudo access)..."
    sudo installer -pkg /tmp/nodejs-install/node-v22.14.0.pkg -target /
    
    rm -rf /tmp/nodejs-install
    
    # Reload PATH
    export PATH="/usr/local/bin:$PATH"
    
    if command -v node &> /dev/null; then
        print_success "Node.js installed successfully"
    else
        print_error "Node.js installation failed"
        return 1
    fi
}

# Function to install Node.js on Linux
install_nodejs_linux() {
    print_info "Installing Node.js for Linux..."
    
    # Try to use NodeSource repository
    if command -v curl &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v wget &> /dev/null; then
        wget -qO- https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        print_error "Neither curl nor wget found. Please install Node.js manually from https://nodejs.org"
        return 1
    fi
    
    if command -v node &> /dev/null; then
        print_success "Node.js installed successfully"
    else
        print_error "Node.js installation failed"
        return 1
    fi
}

# Function to install Node.js
install_nodejs() {
    local os=$(detect_os)
    
    case $os in
        "macos")
            install_nodejs_macos
            ;;
        "linux")
            install_nodejs_linux
            ;;
        "windows")
            print_error "Please install Node.js manually from https://nodejs.org/en/download/"
            print_info "Download the Windows Installer (.msi) and run it"
            exit 1
            ;;
        *)
            print_error "Unsupported OS for automatic Node.js installation"
            print_info "Please install Node.js v18+ manually from https://nodejs.org"
            exit 1
            ;;
    esac
}

# Function to backup existing config
backup_claude_config() {
    local config_path="$1"
    
    if [ -f "$config_path" ]; then
        local backup_path="${config_path}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_path" "$backup_path"
        print_success "Existing config backed up to: $backup_path"
    fi
}

# Function to create or update Claude config
update_claude_config() {
    local config_path="$1"
    local config_dir=$(dirname "$config_path")
    
    # Create config directory if it doesn't exist
    mkdir -p "$config_dir"
    
    # Check if config file exists and has valid JSON
    if [ -f "$config_path" ]; then
        if ! python3 -m json.tool "$config_path" > /dev/null 2>&1 && ! node -e "JSON.parse(require('fs').readFileSync('$config_path', 'utf8'))" > /dev/null 2>&1; then
            print_warning "Existing config file has invalid JSON format"
            backup_claude_config "$config_path"
        fi
    fi
    
    # Create new config or update existing
    if [ ! -f "$config_path" ]; then
        # Create new config
        cat > "$config_path" << 'EOF'
{
  "mcpServers": {
    "desktop-commander": {
      "command": "npx",
      "args": [
        "-y",
        "@wonderwhy-er/desktop-commander"
      ]
    }
  }
}
EOF
        print_success "Created new Claude config file"
    else
        # Update existing config
        backup_claude_config "$config_path"
        
        # Use Python or Node.js to merge JSON
        if command -v python3 &> /dev/null; then
            python3 << EOF
import json
import sys

config_path = "$config_path"

try:
    with open(config_path, 'r') as f:
        config = json.load(f)
except:
    config = {}

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['desktop-commander'] = {
    "command": "npx",
    "args": ["-y", "@wonderwhy-er/desktop-commander"]
}

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print("Claude config updated successfully")
EOF
        elif command -v node &> /dev/null; then
            node << EOF
const fs = require('fs');
const path = '$config_path';

let config = {};
try {
    config = JSON.parse(fs.readFileSync(path, 'utf8'));
} catch (e) {
    config = {};
}

if (!config.mcpServers) {
    config.mcpServers = {};
}

config.mcpServers['desktop-commander'] = {
    command: 'npx',
    args: ['-y', '@wonderwhy-er/desktop-commander']
};

fs.writeFileSync(path, JSON.stringify(config, null, 2));
console.log('Claude config updated successfully');
EOF
        else
            print_error "Neither Python3 nor Node.js available for JSON manipulation"
            return 1
        fi
        
        print_success "Updated existing Claude config file"
    fi
}

# Function to install Desktop Commander
install_desktop_commander() {
    print_info "Installing Desktop Commander MCP..."
    
    # Method 1: Try using the official setup command
    if npx @wonderwhy-er/desktop-commander@latest setup 2>/dev/null; then
        print_success "Desktop Commander installed via setup command"
        return 0
    fi
    
    # Method 2: Try using Smithery
    print_info "Trying Smithery installation method..."
    if npx -y @smithery/cli install @wonderwhy-er/desktop-commander --client claude 2>/dev/null; then
        print_success "Desktop Commander installed via Smithery"
        return 0
    fi
    
    # Method 3: Manual config update
    print_info "Using manual configuration method..."
    local config_path=$(get_claude_config_path)
    update_claude_config "$config_path"
    
    # Test the installation
    if npx -y @wonderwhy-er/desktop-commander --help &> /dev/null; then
        print_success "Desktop Commander package verified"
    else
        print_warning "Package verification failed, but config was updated"
    fi
}

# Function to provide installation instructions
show_next_steps() {
    echo
    print_info "Installation completed! Next steps:"
    echo
    echo "1. 🔄 Restart Claude Desktop completely"
    echo "2. 🔧 Open Claude Desktop settings and go to Developer tab"
    echo "3. ✅ Verify that 'desktop-commander' shows as 'Connected' or 'Running'"
    echo "4. 💬 Start a new chat and ask Claude to help with terminal commands or file operations"
    echo
    print_info "Example commands to try:"
    echo "  • 'List the files in my current directory'"
    echo "  • 'Show me the contents of package.json'"
    echo "  • 'Run npm install in this project'"
    echo
    print_info "Troubleshooting:"
    echo "  • If MCP server shows as disconnected, check Developer settings in Claude"
    echo "  • Join Discord: https://discord.gg/kQ27sNnZr7"
    echo "  • GitHub Issues: https://github.com/wonderwhy-er/DesktopCommanderMCP/issues"
    echo
    print_success "Desktop Commander MCP is ready to use! 🚀"
}

# Function to show installation options
show_installation_options() {
    echo
    print_info "Choose installation method:"
    echo "1. 🚀 Automatic (Recommended) - Full automated setup"
    echo "2. 📦 Smithery - Use Smithery package manager"
    echo "3. ⚙️  Manual - Manual configuration only"
    echo "4. 🌐 Download official script - Use the official installer"
    echo
    read -p "Enter your choice (1-4) [1]: " choice
    choice=${choice:-1}
    
    case $choice in
        1)
            return 0  # Continue with automatic
            ;;
        2)
            print_info "Installing via Smithery..."
            npx -y @smithery/cli install @wonderwhy-er/desktop-commander --client claude
            print_success "Smithery installation completed"
            show_next_steps
            exit 0
            ;;
        3)
            print_info "Manual configuration only..."
            local config_path=$(get_claude_config_path)
            update_claude_config "$config_path"
            show_next_steps
            exit 0
            ;;
        4)
            print_info "Downloading and running official installer..."
            curl -fsSL https://raw.githubusercontent.com/wonderwhy-er/DesktopCommanderMCP/refs/heads/main/install.sh | bash
            exit 0
            ;;
        *)
            print_error "Invalid choice. Using automatic installation."
            return 0
            ;;
    esac
}

# Main installation function
main() {
    print_header
    
    print_info "This script will install Desktop Commander MCP for Claude Desktop"
    print_info "Desktop Commander enables Claude to execute terminal commands and edit files"
    echo
    
    # Check prerequisites
    print_info "Checking prerequisites..."
    check_claude_desktop
    
    # Check and install Node.js if needed
    if ! check_nodejs; then
        print_info "Node.js v18+ is required for Desktop Commander MCP"
        read -p "Would you like to install Node.js automatically? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_error "Node.js is required. Please install it manually from https://nodejs.org"
            exit 1
        fi
        
        install_nodejs
        
        # Verify installation
        if ! check_nodejs; then
            print_error "Node.js installation verification failed"
            exit 1
        fi
    fi
    
    # Show installation options
    show_installation_options
    
    # Proceed with automatic installation
    print_info "Starting automatic installation..."
    
    # Install Desktop Commander
    if install_desktop_commander; then
        print_success "Desktop Commander MCP installation completed successfully!"
    else
        print_error "Installation failed. Please check the error messages above."
        print_info "You can try manual installation by following the documentation at:"
        print_info "https://github.com/wonderwhy-er/DesktopCommanderMCP"
        exit 1
    fi
    
    # Show next steps
    show_next_steps
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi