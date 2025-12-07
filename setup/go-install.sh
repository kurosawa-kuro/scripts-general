#!/bin/bash
# =============================================================================
# Install Go (Golang)
# =============================================================================
#
# This script:
# 1. Downloads and installs Go from official source
# 2. Sets up GOPATH and PATH environment variables
# 3. Verifies installation
#
# Usage:
#   ./go-install.sh [VERSION]
#   ./go-install.sh           # Install latest stable
#   ./go-install.sh 1.22.0    # Install specific version
#
# Environment Variables:
#   GO_VERSION  - Go version to install (default: latest)
#   GOROOT      - Go installation directory (default: /usr/local/go)
#   GOPATH      - Go workspace directory (default: ~/go)
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

# =============================================================================
# Configuration
# =============================================================================

GO_VERSION="${1:-${GO_VERSION:-}}"
GOROOT="${GOROOT:-/usr/local/go}"
GOPATH="${GOPATH:-$HOME/go}"
GO_DOWNLOAD_URL="https://go.dev/dl"

# =============================================================================
# Functions
# =============================================================================

get_latest_version() {
    print_info "Fetching latest Go version..."

    local version=$(curl -sL "https://go.dev/VERSION?m=text" | head -1)

    if [ -z "$version" ]; then
        print_error "Failed to fetch latest version"
        return 1
    fi

    # Remove 'go' prefix if present
    echo "${version#go}"
}

get_installed_version() {
    if command -v go &> /dev/null; then
        go version 2>/dev/null | grep -oP 'go\K[0-9]+\.[0-9]+(\.[0-9]+)?'
    fi
}

detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv*)   arch="armv6l" ;;
    esac

    echo "${os}-${arch}"
}

download_go() {
    local version="$1"
    local platform=$(detect_platform)
    local filename="go${version}.${platform}.tar.gz"
    local url="${GO_DOWNLOAD_URL}/${filename}"
    local tmp_file="/tmp/${filename}"

    print_info "Downloading Go ${version} for ${platform}..."
    print_info "URL: $url"

    if ! curl -fsSL -o "$tmp_file" "$url"; then
        print_error "Failed to download Go"
        print_info "Check if version exists: ${GO_DOWNLOAD_URL}"
        return 1
    fi

    print_success "Downloaded: $tmp_file"
    echo "$tmp_file"
}

install_go() {
    local tarball="$1"

    print_info "Installing Go to $GOROOT..."

    # Remove existing installation
    if [ -d "$GOROOT" ]; then
        print_info "Removing existing Go installation..."
        sudo rm -rf "$GOROOT"
    fi

    # Extract to /usr/local
    sudo tar -C "$(dirname "$GOROOT")" -xzf "$tarball"

    if [ ! -x "$GOROOT/bin/go" ]; then
        print_error "Installation failed: go binary not found"
        return 1
    fi

    print_success "Go installed to $GOROOT"

    # Cleanup
    rm -f "$tarball"
}

setup_environment() {
    print_section "Environment Setup"

    # Create GOPATH directories
    mkdir -p "$GOPATH/bin" "$GOPATH/src" "$GOPATH/pkg"
    print_success "Created GOPATH: $GOPATH"

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
    local go_env='
# Go environment
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin'

    if [ -n "$shell_rc" ]; then
        # Check if already configured
        if grep -q "GOROOT" "$shell_rc" 2>/dev/null; then
            print_info "Go environment already in $shell_rc"
        else
            echo "$go_env" >> "$shell_rc"
            print_success "Added Go environment to $shell_rc"
        fi
    fi

    # Export for current session
    export GOROOT="$GOROOT"
    export GOPATH="$GOPATH"
    export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"
}

verify_installation() {
    print_section "Verification"

    # Use full path to ensure we get the new installation
    local go_bin="$GOROOT/bin/go"

    if [ ! -x "$go_bin" ]; then
        print_error "Go binary not found at $go_bin"
        return 1
    fi

    local version=$("$go_bin" version)
    print_success "Installed: $version"

    # Show environment
    print_info "GOROOT: $GOROOT"
    print_info "GOPATH: $GOPATH"

    # Test compilation
    print_info "Testing Go compilation..."

    local test_file=$(mktemp /tmp/go-test-XXXXXX.go)
    cat > "$test_file" <<'GOCODE'
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go!")
}
GOCODE

    if "$go_bin" run "$test_file" 2>/dev/null | grep -q "Hello, Go!"; then
        print_success "Go compilation test passed"
    else
        print_warning "Go compilation test failed"
    fi

    rm -f "$test_file"
}

print_usage() {
    echo "Install Go (Golang)"
    echo ""
    echo "Usage:"
    echo "  $0 [VERSION]"
    echo "  $0              # Install latest stable"
    echo "  $0 1.22.0       # Install specific version"
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  GO_VERSION      Go version to install"
    echo "  GOROOT          Installation directory (default: /usr/local/go)"
    echo "  GOPATH          Workspace directory (default: ~/go)"
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Help
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        print_usage
        exit 0
    fi

    print_header "Install Go"

    # Check prerequisites
    print_section "Prerequisites"

    if ! require_curl; then
        return 1
    fi

    # Check current installation
    local current_version=$(get_installed_version)
    if [ -n "$current_version" ]; then
        print_info "Current Go version: $current_version"
    fi

    # Determine version to install
    print_section "Version"

    if [ -z "$GO_VERSION" ]; then
        GO_VERSION=$(get_latest_version)
        if [ -z "$GO_VERSION" ]; then
            return 1
        fi
    fi

    print_info "Target version: $GO_VERSION"

    # Check if already installed
    if [ "$current_version" = "$GO_VERSION" ]; then
        print_success "Go $GO_VERSION is already installed"
        verify_installation
        return 0
    fi

    # Confirm installation
    if [ -n "$current_version" ]; then
        print_warning "This will upgrade Go from $current_version to $GO_VERSION"
    fi

    # Download
    print_section "Download"

    local tarball=$(download_go "$GO_VERSION")
    if [ -z "$tarball" ] || [ ! -f "$tarball" ]; then
        return 1
    fi

    # Install
    print_section "Installation"

    if ! install_go "$tarball"; then
        return 1
    fi

    # Setup environment
    setup_environment

    # Verify
    verify_installation

    # Summary
    echo ""
    print_success "Go $GO_VERSION installed successfully!"
    echo ""
    print_info "To use Go in this terminal, run:"
    echo "  source ~/.bashrc  # or ~/.zshrc"
    echo ""
    print_info "Or start a new terminal session"

    return 0
}

main "$@"
exit $?
