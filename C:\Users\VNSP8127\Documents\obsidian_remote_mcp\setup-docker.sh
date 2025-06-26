#!/bin/bash
# Docker development scripts for Obsidian Remote MCP

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "Docker and Docker Compose are installed"
}

# Check if ports are available
check_ports() {
    local ports=(3010 3011 8010 5442 6389 8080)
    
    print_status "Checking port availability..."
    
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port is already in use"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Aborted due to port conflicts"
                exit 1
            fi
        fi
    done
    
    print_success "Port check completed"
}

# Setup environment
setup_env() {
    print_status "Setting up environment..."
    
    if [ ! -f .env ]; then
        cp .env.example .env
        print_success "Created .env file from .env.example"
        print_warning "Please edit .env file with your API keys and settings"
    else
        print_status ".env file already exists"
    fi
}

# Main setup function
main() {
    print_status "Starting Obsidian Remote MCP Docker setup..."
    
    check_docker
    check_ports
    setup_env
    
    print_success "Setup completed!"
    print_status "Next steps:"
    echo "1. Edit .env file with your settings"
    echo "2. Run: docker-compose up -d"
    echo "3. Access the application at: http://localhost:8080"
    echo ""
    echo "Available services:"
    echo "- Main App: http://localhost:8080"
    echo "- MCP Server: http://localhost:3010"
    echo "- Dashboard: http://localhost:3011"
    echo "- Vector DB: http://localhost:8010"
    echo "- PostgreSQL: localhost:5442"
}

main "$@"