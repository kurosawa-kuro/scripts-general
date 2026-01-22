#!/bin/bash
# =============================================================================
# Claude Code Setup Script
# =============================================================================
# Purpose: Install/Update Node.js, npm, and @anthropic-ai/claude-code
# Usage:
#   bash scripts/setup/setup-claude-code.sh          # Interactive mode
#   bash scripts/setup/setup-claude-code.sh --force  # Skip confirmation
#   bash scripts/setup/setup-claude-code.sh --skip-node-check # Skip Node.js version check
#
# Features:
#   - Checks and installs Node.js 18+ and npm if not present
#   - Cleans up existing Claude Code installation
#   - Reinstalls Claude Code globally
#   - Sets up 'cc' alias for 'claude' command
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
REQUIRED_NODE_MAJOR_VERSION=18
CLAUDE_CODE_PACKAGE="@anthropic-ai/claude-code"
NPM_GLOBAL_DIR="$HOME/.npm-global"

# Flags
FORCE_MODE=false
SKIP_NODE_CHECK=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --force|-f)
            FORCE_MODE=true
            shift
            ;;
        --skip-node-check)
            SKIP_NODE_CHECK=true
            shift
            ;;
        --help|-h)
            echo "Claude Code Setup Script"
            echo ""
            echo "Usage:"
            echo "  $0                     # Interactive mode (default)"
            echo "  $0 --force             # Skip confirmation prompts"
            echo "  $0 --skip-node-check   # Skip Node.js version check"
            echo "  $0 --help              # Show this help message"
            echo ""
            echo "This script will:"
            echo "  1. Check Node.js and npm installation"
            echo "  2. Install Node.js ${REQUIRED_NODE_MAJOR_VERSION}+ if not present"
            echo "  3. Clean up existing Claude Code installation"
            echo "  4. Install Claude Code globally"
            echo "  5. Set up 'cc' alias for 'claude' command"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Print header
echo -e "${CYAN}${BOLD}"
echo "=========================================================================="
echo "  Claude Code Setup Script"
echo "=========================================================================="
echo -e "${NC}"

# =============================================================================
# Function: Check if command exists
# =============================================================================
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# Function: Get Node.js major version
# =============================================================================
get_node_major_version() {
    if command_exists node; then
        node --version | sed 's/v\([0-9]*\).*/\1/'
    else
        echo "0"
    fi
}

# =============================================================================
# Function: Install Node.js and npm
# =============================================================================
install_nodejs() {
    echo -e "${YELLOW}Node.js ${REQUIRED_NODE_MAJOR_VERSION}+ is required but not found.${NC}"

    if [ "$FORCE_MODE" = false ]; then
        echo -e "${CYAN}Do you want to install Node.js ${REQUIRED_NODE_MAJOR_VERSION}+ and npm? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Installation cancelled.${NC}"
            exit 1
        fi
    fi

    echo -e "${BLUE}Installing Node.js and npm...${NC}"

    # Update package list
    sudo apt-get update

    # Install curl if not present
    if ! command_exists curl; then
        echo -e "${BLUE}Installing curl...${NC}"
        sudo apt-get install -y curl
    fi

    # Install Node.js using NodeSource repository
    echo -e "${BLUE}Adding NodeSource repository for Node.js ${REQUIRED_NODE_MAJOR_VERSION}...${NC}"
    curl -fsSL "https://deb.nodesource.com/setup_${REQUIRED_NODE_MAJOR_VERSION}.x" | sudo -E bash -

    echo -e "${BLUE}Installing Node.js...${NC}"
    sudo apt-get install -y nodejs

    # Verify installation
    if command_exists node && command_exists npm; then
        echo -e "${GREEN}✓ Node.js $(node --version) installed successfully${NC}"
        echo -e "${GREEN}✓ npm $(npm --version) installed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to install Node.js or npm${NC}"
        exit 1
    fi
}

# =============================================================================
# Function: Setup npm global directory
# =============================================================================
setup_npm_global_dir() {
    if [ ! -d "$NPM_GLOBAL_DIR" ]; then
        echo -e "${BLUE}Creating npm global directory: $NPM_GLOBAL_DIR${NC}"
        mkdir -p "$NPM_GLOBAL_DIR"
        npm config set prefix "$NPM_GLOBAL_DIR"

        # Add to PATH if not already present
        if [[ ":$PATH:" != *":$NPM_GLOBAL_DIR/bin:"* ]]; then
            echo -e "${YELLOW}Adding $NPM_GLOBAL_DIR/bin to PATH${NC}"
            echo "export PATH=\"$NPM_GLOBAL_DIR/bin:\$PATH\"" >> "$HOME/.bashrc"
            export PATH="$NPM_GLOBAL_DIR/bin:$PATH"
        fi
    fi
}

# =============================================================================
# Function: Clean up Claude Code
# =============================================================================
cleanup_claude_code() {
    echo -e "${BLUE}Cleaning up existing Claude Code installation...${NC}"

    # Remove global package
    if [ -d "$NPM_GLOBAL_DIR/lib/node_modules/$CLAUDE_CODE_PACKAGE" ]; then
        echo -e "${YELLOW}Removing existing package from $NPM_GLOBAL_DIR${NC}"
        rm -rf "$NPM_GLOBAL_DIR/lib/node_modules/$CLAUDE_CODE_PACKAGE"
    fi

    # Clean npm cache
    echo -e "${BLUE}Cleaning npm cache...${NC}"
    npm cache clean --force

    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# =============================================================================
# Function: Install Claude Code
# =============================================================================
install_claude_code() {
    echo -e "${BLUE}Installing Claude Code globally...${NC}"

    if npm install -g "$CLAUDE_CODE_PACKAGE"; then
        echo -e "${GREEN}✓ Claude Code installed successfully${NC}"

        # Verify installation
        if command_exists claude-code; then
            echo -e "${GREEN}✓ claude-code command is available${NC}"
        else
            echo -e "${YELLOW}⚠ claude-code installed but command not found in PATH${NC}"
            echo -e "${YELLOW}  You may need to restart your shell or run: source ~/.bashrc${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to install Claude Code${NC}"
        exit 1
    fi
}

# =============================================================================
# Function: Setup alias for Claude Code
# =============================================================================
setup_alias() {
    echo -e "${BLUE}Setting up 'cc' alias for 'claude' command...${NC}"

    local bashrc_file="$HOME/.bashrc"
    local alias_line="alias cc='claude'"
    local alias_comment="# Claude Code alias (added by setup-claude-code.sh)"

    # Check if alias already exists
    if grep -q "^alias cc=" "$bashrc_file" 2>/dev/null; then
        echo -e "${YELLOW}Alias 'cc' already exists in $bashrc_file${NC}"
        
        # Check if it's the correct alias
        if grep -q "^alias cc='claude'" "$bashrc_file" 2>/dev/null; then
            echo -e "${GREEN}✓ Alias 'cc' is already correctly configured${NC}"
            return 0
        else
            echo -e "${YELLOW}Existing 'cc' alias found but points to different command${NC}"
            if [ "$FORCE_MODE" = false ]; then
                echo -e "${CYAN}Do you want to update it? (y/N)${NC}"
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}Skipping alias setup${NC}"
                    return 0
                fi
            fi
            # Remove existing alias line
            sed -i "/^alias cc=/d" "$bashrc_file"
        fi
    fi

    # Add alias to .bashrc
    echo "" >> "$bashrc_file"
    echo "$alias_comment" >> "$bashrc_file"
    echo "$alias_line" >> "$bashrc_file"
    
    echo -e "${GREEN}✓ Alias 'cc' added to $bashrc_file${NC}"
    
    # Also set alias in current shell session
    alias cc='claude'
    echo -e "${GREEN}✓ Alias 'cc' is now available in current session${NC}"
}

# =============================================================================
# Main Execution
# =============================================================================

echo -e "${CYAN}Step 1: Checking Node.js and npm...${NC}"

# Check Node.js version
if [ "$SKIP_NODE_CHECK" = false ]; then
    NODE_MAJOR_VERSION=$(get_node_major_version)

    if [ "$NODE_MAJOR_VERSION" -lt "$REQUIRED_NODE_MAJOR_VERSION" ]; then
        if [ "$NODE_MAJOR_VERSION" -eq "0" ]; then
            echo -e "${YELLOW}Node.js is not installed${NC}"
        else
            echo -e "${YELLOW}Node.js version $(node --version) is too old (requires v${REQUIRED_NODE_MAJOR_VERSION}+)${NC}"
        fi
        install_nodejs
    else
        echo -e "${GREEN}✓ Node.js $(node --version) is installed${NC}"
    fi
else
    echo -e "${YELLOW}Skipping Node.js version check (--skip-node-check flag)${NC}"
fi

# Check npm
if ! command_exists npm; then
    echo -e "${RED}✗ npm is not installed${NC}"
    install_nodejs
else
    echo -e "${GREEN}✓ npm $(npm --version) is installed${NC}"
fi

echo ""
echo -e "${CYAN}Step 2: Setting up npm global directory...${NC}"
setup_npm_global_dir

echo ""
echo -e "${CYAN}Step 3: Cleaning up existing Claude Code installation...${NC}"

if [ "$FORCE_MODE" = false ]; then
    echo -e "${YELLOW}This will remove existing Claude Code installation and clean npm cache.${NC}"
    echo -e "${CYAN}Continue? (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operation cancelled.${NC}"
        exit 1
    fi
fi

cleanup_claude_code

echo ""
echo -e "${CYAN}Step 4: Installing Claude Code...${NC}"
install_claude_code

echo ""
echo -e "${CYAN}Step 5: Setting up alias...${NC}"
setup_alias

echo ""
echo -e "${GREEN}${BOLD}"
echo "=========================================================================="
echo "  ✓ Setup Completed Successfully"
echo "=========================================================================="
echo -e "${NC}"
echo -e "${CYAN}Summary:${NC}"
echo -e "  ${GREEN}✓${NC} Node.js: $(node --version)"
echo -e "  ${GREEN}✓${NC} npm: $(npm --version)"
echo -e "  ${GREEN}✓${NC} Claude Code: installed globally"
echo -e "  ${GREEN}✓${NC} Alias 'cc': configured for 'claude' command"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Restart your shell or run: ${BOLD}source ~/.bashrc${NC}"
echo -e "  2. Verify installation: ${BOLD}claude --version${NC} or ${BOLD}cc --version${NC}"
echo -e "  3. Start using: ${BOLD}claude${NC} or ${BOLD}cc${NC}"
echo ""
