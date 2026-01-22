#!/bin/bash
# =============================================================================
# Node.js LTS Setup Script
# =============================================================================
# Purpose: Install Node.js LTS on Ubuntu using NodeSource repository
# Usage:
#   bash scripts/general/setup-nodejs.sh                # Install Node.js LTS
#   bash scripts/general/setup-nodejs.sh --version      # Show installed version
#   bash scripts/general/setup-nodejs.sh --uninstall    # Uninstall Node.js
#   bash scripts/general/setup-nodejs.sh --help         # Show help
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
NODEJS_LTS_VERSION="lts"
NODESOURCE_SCRIPT_URL="https://deb.nodesource.com/setup_lts.x"

# =============================================================================
# Functions
# =============================================================================

print_header() {
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}--- $1 ---${NC}"
}

print_usage() {
    echo "Node.js LTS Setup Script"
    echo ""
    echo "Usage:"
    echo "  $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  (no args)       Install Node.js LTS (default)"
    echo "  --version       Show installed Node.js and npm versions"
    echo "  --uninstall     Uninstall Node.js"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install Node.js LTS"
    echo "  $0 --version          # Show versions"
    echo "  $0 --uninstall        # Uninstall Node.js"
}

check_ubuntu() {
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}✗${NC} Cannot detect OS. This script is for Ubuntu only."
        exit 1
    fi

    source /etc/os-release
    if [ "$ID" != "ubuntu" ] && [ "$ID" != "debian" ]; then
        echo -e "${YELLOW}⚠${NC}  This script is designed for Ubuntu/Debian. Detected: $ID"
        read -p "Continue anyway? (y/N): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    echo -e "${GREEN}✓${NC} OS: $PRETTY_NAME"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${YELLOW}⚠${NC}  Running as root. Some commands may need sudo."
    fi
}

check_nodejs_installed() {
    if command -v node &> /dev/null; then
        local current_version=$(node --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} Node.js is already installed: ${CYAN}$current_version${NC}"
        return 0
    else
        return 1
    fi
}

check_npm_installed() {
    if command -v npm &> /dev/null; then
        local current_version=$(npm --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} npm is already installed: ${CYAN}$current_version${NC}"
        return 0
    else
        return 1
    fi
}

show_version() {
    print_header "Node.js Version Information"

    if check_nodejs_installed; then
        local node_version=$(node --version)
        echo -e "${MAGENTA}Node.js:${NC} ${GREEN}$node_version${NC}"
    else
        echo -e "${MAGENTA}Node.js:${NC} ${RED}Not installed${NC}"
    fi

    echo ""

    if check_npm_installed; then
        local npm_version=$(npm --version)
        echo -e "${MAGENTA}npm:${NC} ${GREEN}$npm_version${NC}"
    else
        echo -e "${MAGENTA}npm:${NC} ${RED}Not installed${NC}"
    fi

    echo ""

    # Show additional info
    if command -v node &> /dev/null; then
        echo -e "${MAGENTA}Node.js path:${NC} $(which node)"
        echo -e "${MAGENTA}npm path:${NC} $(which npm 2>/dev/null || echo 'Not found')"
    fi
}

install_curl() {
    if ! command -v curl &> /dev/null; then
        print_section "Installing curl"
        echo -e "${YELLOW}⏳ Installing curl...${NC}"
        sudo apt-get update -qq
        sudo apt-get install -y curl
        echo -e "${GREEN}✓${NC} curl installed"
    else
        echo -e "${GREEN}✓${NC} curl is already installed"
    fi
}

add_nodesource_repository() {
    print_section "Adding NodeSource Repository"

    echo -e "${YELLOW}⏳ Downloading NodeSource setup script...${NC}"
    
    # Download and run NodeSource setup script
    curl -fsSL $NODESOURCE_SCRIPT_URL | sudo -E bash - || {
        echo -e "${RED}✗${NC} Failed to add NodeSource repository"
        exit 1
    }

    echo -e "${GREEN}✓${NC} NodeSource repository added"
}

install_nodejs() {
    print_section "Installing Node.js LTS"

    echo -e "${YELLOW}⏳ Installing Node.js LTS...${NC}"
    
    sudo apt-get update -qq
    sudo apt-get install -y nodejs

    echo -e "${GREEN}✓${NC} Node.js LTS installed"
}

verify_installation() {
    print_section "Verifying Installation"

    if check_nodejs_installed; then
        local node_version=$(node --version)
        echo -e "${GREEN}✓${NC} Node.js installed: ${CYAN}$node_version${NC}"
    else
        echo -e "${RED}✗${NC} Node.js installation verification failed"
        exit 1
    fi

    if check_npm_installed; then
        local npm_version=$(npm --version)
        echo -e "${GREEN}✓${NC} npm installed: ${CYAN}$npm_version${NC}"
    else
        echo -e "${YELLOW}⚠${NC}  npm not found (this is unusual)"
    fi
}

install_nodejs_lts() {
    print_header "Installing Node.js LTS"

    check_ubuntu
    check_root

    # Check if already installed
    if check_nodejs_installed; then
        echo ""
        echo -e "${YELLOW}⚠${NC}  Node.js is already installed"
        echo ""
        show_version
        echo ""
        read -p "Do you want to reinstall? (y/N): " -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Installation cancelled.${NC}"
            exit 0
        fi

        # Uninstall existing version
        echo -e "${YELLOW}⏳ Removing existing Node.js...${NC}"
        sudo apt-get remove -y nodejs npm 2>/dev/null || true
        sudo apt-get purge -y nodejs npm 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Existing installation removed"
    fi

    # Install curl if needed
    install_curl

    # Add NodeSource repository
    add_nodesource_repository

    # Install Node.js
    install_nodejs

    # Verify installation
    verify_installation

    echo ""
    echo -e "${GREEN}${BOLD}✅ Node.js LTS installation completed!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Verify installation: ${YELLOW}node --version${NC}"
    echo -e "  2. Verify npm: ${YELLOW}npm --version${NC}"
    echo -e "  3. Update npm: ${YELLOW}sudo npm install -g npm@latest${NC} (optional)"
}

uninstall_nodejs() {
    print_header "Uninstalling Node.js"

    if ! check_nodejs_installed; then
        echo -e "${YELLOW}⚠${NC}  Node.js is not installed"
        exit 0
    fi

    # Show current version
    echo ""
    show_version
    echo ""

    # Confirm uninstall
    echo -e "${YELLOW}⚠${NC}  This will remove Node.js and npm."
    echo ""
    read -p "Are you sure you want to uninstall Node.js? (y/N): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
        exit 0
    fi

    # Remove Node.js and npm
    print_section "Removing Node.js and npm"
    
    echo -e "${YELLOW}⏳ Removing Node.js and npm...${NC}"
    sudo apt-get remove -y nodejs npm 2>/dev/null || true
    sudo apt-get purge -y nodejs npm 2>/dev/null || true
    
    # Remove NodeSource repository
    echo -e "${YELLOW}⏳ Removing NodeSource repository...${NC}"
    sudo rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
    sudo rm -f /etc/apt/sources.list.d/nodesource.list.save 2>/dev/null || true
    
    # Update apt cache
    sudo apt-get update -qq

    echo ""
    echo -e "${GREEN}${BOLD}✅ Node.js uninstalled successfully!${NC}"
}

# =============================================================================
# Parse Arguments
# =============================================================================

COMMAND="install"

if [ $# -gt 0 ]; then
    case $1 in
        --version)
            COMMAND="version"
            ;;
        --uninstall)
            COMMAND="uninstall"
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
            print_usage
            exit 1
            ;;
    esac
fi

# =============================================================================
# Main Script
# =============================================================================

case $COMMAND in
    install)
        install_nodejs_lts
        ;;
    version)
        show_version
        ;;
    uninstall)
        uninstall_nodejs
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        exit 1
        ;;
esac

