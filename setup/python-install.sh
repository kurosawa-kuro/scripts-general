#!/bin/bash
# =============================================================================
# Python Setup Script
# =============================================================================
# Purpose: Install Python (pyenv) with pip and venv support
# Usage:
#   ./python-install.sh                # Install latest Python
#   ./python-install.sh 3.12.0         # Install specific version
#   ./python-install.sh --version      # Show installed version
#   ./python-install.sh --list         # List available versions
#   ./python-install.sh --help         # Show help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

# =============================================================================
# Configuration
# =============================================================================

PYTHON_VERSION="${1:-}"
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Python Setup Script (using pyenv)"
    echo ""
    echo "Usage:"
    echo "  $0 [VERSION]"
    echo "  $0                    # Install latest Python"
    echo "  $0 3.12.0             # Install specific version"
    echo "  $0 --version          # Show installed versions"
    echo "  $0 --list             # List available versions"
    echo "  $0 --uninstall        # Uninstall pyenv"
    echo "  $0 --help             # Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  PYENV_ROOT            pyenv directory (default: ~/.pyenv)"
}

check_pyenv_installed() {
    if [ -d "$PYENV_ROOT" ] && [ -x "$PYENV_ROOT/bin/pyenv" ]; then
        return 0
    fi
    return 1
}

get_latest_python_version() {
    # Get latest stable Python 3.x version
    "$PYENV_ROOT/bin/pyenv" install --list 2>/dev/null | \
        grep -E "^\s+3\.[0-9]+\.[0-9]+$" | \
        tail -1 | \
        tr -d ' '
}

install_dependencies() {
    print_section "Installing Build Dependencies"

    if [ -f /etc/debian_version ]; then
        print_info "Detected Debian/Ubuntu"
        sudo apt-get update -qq
        sudo apt-get install -y \
            build-essential \
            libssl-dev \
            zlib1g-dev \
            libbz2-dev \
            libreadline-dev \
            libsqlite3-dev \
            curl \
            libncursesw5-dev \
            xz-utils \
            tk-dev \
            libxml2-dev \
            libxmlsec1-dev \
            libffi-dev \
            liblzma-dev \
            git
        print_success "Dependencies installed"
    elif [ -f /etc/redhat-release ]; then
        print_info "Detected RHEL/CentOS/Fedora"
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y \
            openssl-devel \
            bzip2-devel \
            libffi-devel \
            xz-devel \
            readline-devel \
            sqlite-devel \
            git
        print_success "Dependencies installed"
    else
        print_warning "Unknown OS. Please install build dependencies manually."
    fi
}

install_pyenv() {
    print_section "Installing pyenv"

    if check_pyenv_installed; then
        print_info "pyenv is already installed at $PYENV_ROOT"
        return 0
    fi

    print_info "Downloading pyenv..."
    curl -fsSL https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash

    print_success "pyenv installed to $PYENV_ROOT"
}

setup_environment() {
    print_section "Environment Setup"

    # Determine shell config file
    local shell_rc=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -f "$HOME/.profile" ]; then
        shell_rc="$HOME/.profile"
    fi

    # Environment variables to add
    local pyenv_env='
# pyenv environment
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"'

    if [ -n "$shell_rc" ]; then
        if grep -q "PYENV_ROOT" "$shell_rc" 2>/dev/null; then
            print_info "pyenv environment already in $shell_rc"
        else
            echo "$pyenv_env" >> "$shell_rc"
            print_success "Added pyenv environment to $shell_rc"
        fi
    fi

    # Export for current session
    export PYENV_ROOT="$PYENV_ROOT"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$("$PYENV_ROOT/bin/pyenv" init -)"
}

install_python() {
    local version="$1"

    print_section "Installing Python $version"

    # Check if already installed
    if "$PYENV_ROOT/bin/pyenv" versions --bare | grep -q "^${version}$"; then
        print_info "Python $version is already installed"
    else
        print_info "Installing Python $version (this may take a while)..."
        "$PYENV_ROOT/bin/pyenv" install "$version"
        print_success "Python $version installed"
    fi

    # Set as global default
    "$PYENV_ROOT/bin/pyenv" global "$version"
    print_success "Python $version set as global default"
}

verify_installation() {
    print_section "Verification"

    # Rehash pyenv
    "$PYENV_ROOT/bin/pyenv" rehash

    local python_path=$("$PYENV_ROOT/bin/pyenv" which python 2>/dev/null || echo "")
    if [ -z "$python_path" ]; then
        print_error "Python not found"
        return 1
    fi

    local python_version=$("$python_path" --version 2>&1)
    print_success "Python: $python_version"
    print_info "Path: $python_path"

    # Check pip
    local pip_path=$("$PYENV_ROOT/bin/pyenv" which pip 2>/dev/null || echo "")
    if [ -n "$pip_path" ]; then
        local pip_version=$("$pip_path" --version 2>&1)
        print_success "pip: $pip_version"
    else
        print_warning "pip not found"
    fi

    # Test venv
    print_info "Testing venv module..."
    if "$python_path" -m venv --help &>/dev/null; then
        print_success "venv module available"
    else
        print_warning "venv module not available"
    fi
}

show_version() {
    print_header "Python Version Information"

    if ! check_pyenv_installed; then
        print_warning "pyenv is not installed"

        # Check system Python
        if command -v python3 &>/dev/null; then
            print_info "System Python: $(python3 --version)"
        fi
        return 0
    fi

    # Setup pyenv for current session
    export PYENV_ROOT="$PYENV_ROOT"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$("$PYENV_ROOT/bin/pyenv" init -)"

    print_info "pyenv root: $PYENV_ROOT"
    echo ""

    print_section "Installed Versions"
    "$PYENV_ROOT/bin/pyenv" versions

    echo ""
    print_section "Current Version"
    local current=$("$PYENV_ROOT/bin/pyenv" version)
    print_info "$current"
}

list_versions() {
    print_header "Available Python Versions"

    if ! check_pyenv_installed; then
        print_error "pyenv is not installed. Run this script first to install pyenv."
        return 1
    fi

    print_info "Showing Python 3.x versions (last 20):"
    echo ""
    "$PYENV_ROOT/bin/pyenv" install --list 2>/dev/null | \
        grep -E "^\s+3\.[0-9]+\.[0-9]+$" | \
        tail -20
}

uninstall_pyenv() {
    print_header "Uninstalling pyenv"

    if ! check_pyenv_installed; then
        print_warning "pyenv is not installed"
        return 0
    fi

    print_warning "This will remove pyenv and all installed Python versions"
    if ! confirm "Continue?"; then
        print_info "Cancelled"
        return 0
    fi

    rm -rf "$PYENV_ROOT"
    print_success "pyenv removed from $PYENV_ROOT"

    print_info "Please remove pyenv configuration from your shell rc file manually"
}

# =============================================================================
# Main
# =============================================================================

main() {
    case "${1:-}" in
        --help|-h)
            print_usage
            exit 0
            ;;
        --version|-v)
            show_version
            exit 0
            ;;
        --list|-l)
            list_versions
            exit 0
            ;;
        --uninstall)
            uninstall_pyenv
            exit 0
            ;;
    esac

    print_header "Install Python (pyenv)"

    # Install dependencies
    install_dependencies

    # Install pyenv
    install_pyenv

    # Setup environment
    setup_environment

    # Determine version to install
    print_section "Version Selection"

    if [ -n "$PYTHON_VERSION" ] && [[ ! "$PYTHON_VERSION" =~ ^-- ]]; then
        print_info "Target version: $PYTHON_VERSION"
    else
        PYTHON_VERSION=$(get_latest_python_version)
        print_info "Latest stable version: $PYTHON_VERSION"
    fi

    # Install Python
    install_python "$PYTHON_VERSION"

    # Verify installation
    verify_installation

    # Summary
    echo ""
    print_success "Python installation completed!"
    echo ""
    print_info "To use Python in this terminal, run:"
    echo "  source ~/.bashrc  # or ~/.zshrc"
    echo ""
    print_info "Create virtual environment:"
    echo "  python -m venv .venv"
    echo "  source .venv/bin/activate"

    return 0
}

main "$@"
exit $?
