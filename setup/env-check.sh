#!/bin/bash
# =============================================================================
# Check Development Environment Setup
# =============================================================================
#
# This script:
# 1. Checks if required development tools are installed
# 2. Shows version information for each tool
# 3. Reports missing tools
#
# Usage:
#   ./check-setup.sh
#   ./check-setup.sh --all    # Include optional tools
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

# =============================================================================
# Configuration
# =============================================================================

CHECK_ALL=false

# Parse arguments
if [ "$1" = "--all" ] || [ "$1" = "-a" ]; then
    CHECK_ALL=true
fi

# =============================================================================
# Functions
# =============================================================================

check_tool() {
    local name="$1"
    local cmd="$2"
    local version_cmd="${3:-$cmd --version}"
    local install_hint="${4:-}"

    printf "  %-14s" "$name"

    if command -v "$cmd" &> /dev/null; then
        local version=$(eval "$version_cmd" 2>/dev/null | head -1)
        echo -e "${GREEN}[OK]${NC} $version"
        return 0
    else
        echo -e "${RED}[NOT FOUND]${NC}"
        if [ -n "$install_hint" ]; then
            echo -e "              ${DIM}→ $install_hint${NC}"
        fi
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header "Development Environment Check"

    local missing=0

    # --- Essential Tools ---
    print_section "Essential Tools"

    check_tool "Git" "git" "git --version" || ((missing++))
    check_tool "Curl" "curl" "curl --version | head -1" || ((missing++))
    check_tool "jq" "jq" "jq --version" "sudo apt install jq" || ((missing++))

    # --- Runtime ---
    print_section "Runtime & Languages"

    check_tool "Node.js" "node" "node --version" "make setup-node" || ((missing++))
    check_tool "npm" "npm" "npm --version" || ((missing++))
    check_tool "Python" "python3" "python3 --version" || ((missing++))
    check_tool "Go" "go" "go version" || ((missing++))

    # --- Cloud & Infrastructure ---
    print_section "Cloud & Infrastructure"

    check_tool "AWS CLI" "aws" "aws --version" || ((missing++))
    check_tool "Terraform" "terraform" "terraform --version | head -1" || ((missing++))

    # --- Containers & K8s ---
    print_section "Containers & Kubernetes"

    check_tool "Docker" "docker" "docker --version" || ((missing++))
    check_tool "kind" "kind" "kind version" || ((missing++))
    check_tool "kubectl" "kubectl" "kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1" || ((missing++))
    check_tool "Helm" "helm" "helm version --short" || ((missing++))

    # --- Development Tools ---
    print_section "Development Tools"

    check_tool "Claude" "claude" "claude --version 2>/dev/null || echo 'installed'" "make setup-claude" || ((missing++))

    # --- Optional Tools ---
    if [ "$CHECK_ALL" = true ]; then
        print_section "Optional Tools"

        check_tool "Make" "make" "make --version | head -1" || true
        check_tool "htop" "htop" "htop --version | head -1" || true
        check_tool "tree" "tree" "tree --version" || true
        check_tool "bat" "bat" "bat --version | head -1" || true
        check_tool "ripgrep" "rg" "rg --version | head -1" || true
        check_tool "fd" "fd" "fd --version" || true
        check_tool "fzf" "fzf" "fzf --version" || true
        check_tool "lazygit" "lazygit" "lazygit --version" || true
        check_tool "lazydocker" "lazydocker" "lazydocker --version" || true
    fi

    # --- Summary ---
    echo ""
    print_section "Summary"

    if [ $missing -eq 0 ]; then
        print_success "All essential tools are installed!"
    else
        print_warning "$missing tool(s) not found"
        echo ""
        print_info "Install missing tools with the setup scripts:"
        echo "  make setup-node     # Node.js"
        echo "  make setup-claude   # Claude Code"
    fi

    if [ "$CHECK_ALL" = false ]; then
        echo ""
        print_info "Run with --all to check optional tools"
    fi

    return 0
}

main "$@"
