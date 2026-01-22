#!/bin/bash
# =============================================================================
# AWS CLI v2 Installation
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"

print_usage() {
    echo "AWS CLI v2 Installation"
    echo ""
    echo "Usage:"
    echo "  $0                # Install AWS CLI v2"
    echo "  $0 --version      # Show installed version"
    echo "  $0 --uninstall    # Uninstall AWS CLI"
    echo "  $0 --help         # Show this help"
}

get_installed_version() {
    aws --version 2>/dev/null | awk '{print $1}' | cut -d'/' -f2
}

install_aws_cli() {
    print_header "Install AWS CLI v2"

    # Check if already installed
    if command -v aws &>/dev/null; then
        local version=$(get_installed_version)
        print_info "AWS CLI already installed: v$version"

        if ! confirm "Reinstall?"; then
            return 0
        fi
    fi

    # Detect platform
    local platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    print_section "Downloading"

    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"

    if [ "$platform" = "linux" ]; then
        if [ "$arch" = "x86_64" ]; then
            curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        elif [ "$arch" = "aarch64" ]; then
            curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
        fi
    elif [ "$platform" = "darwin" ]; then
        curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    fi

    print_success "Downloaded"

    print_section "Installing"

    if [ "$platform" = "linux" ]; then
        unzip -q awscliv2.zip
        sudo ./aws/install --update
    elif [ "$platform" = "darwin" ]; then
        sudo installer -pkg AWSCLIV2.pkg -target /
    fi

    cd - >/dev/null
    rm -rf "$tmp_dir"

    print_success "AWS CLI installed"

    print_section "Verification"
    aws --version

    echo ""
    print_info "Configure: aws configure"
}

case "${1:-}" in
    --help|-h) print_usage; exit 0 ;;
    --version|-v) aws --version 2>/dev/null || echo "Not installed"; exit 0 ;;
    --uninstall) sudo rm -rf /usr/local/aws-cli /usr/local/bin/aws /usr/local/bin/aws_completer; print_success "Uninstalled"; exit 0 ;;
esac

install_aws_cli
