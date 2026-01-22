#!/bin/bash
# =============================================================================
# Terraform Setup Script
# =============================================================================
# Purpose: Install Terraform from HashiCorp official repository
# Usage:
#   ./terraform-install.sh                # Install latest Terraform
#   ./terraform-install.sh 1.7.0          # Install specific version
#   ./terraform-install.sh --version      # Show installed version
#   ./terraform-install.sh --uninstall    # Uninstall Terraform
#   ./terraform-install.sh --help         # Show help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

# =============================================================================
# Configuration
# =============================================================================

TERRAFORM_VERSION="${1:-}"
INSTALL_DIR="/usr/local/bin"

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Terraform Setup Script"
    echo ""
    echo "Usage:"
    echo "  $0 [VERSION]"
    echo "  $0                    # Install latest Terraform"
    echo "  $0 1.7.0              # Install specific version"
    echo "  $0 --version          # Show installed version"
    echo "  $0 --uninstall        # Uninstall Terraform"
    echo "  $0 --help             # Show this help"
}

check_terraform_installed() {
    command -v terraform &>/dev/null
}

get_installed_version() {
    if check_terraform_installed; then
        terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || \
        terraform version 2>/dev/null | head -1 | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+'
    fi
}

get_latest_version() {
    print_info "Fetching latest Terraform version..."

    local version=$(curl -sL https://api.github.com/repos/hashicorp/terraform/releases/latest | \
        jq -r '.tag_name' | sed 's/^v//')

    if [ -z "$version" ] || [ "$version" = "null" ]; then
        # Fallback: scrape from releases page
        version=$(curl -sL https://releases.hashicorp.com/terraform/ | \
            grep -oP 'terraform_\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi

    if [ -z "$version" ]; then
        print_error "Failed to fetch latest version"
        return 1
    fi

    echo "$version"
}

detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv*)   arch="arm" ;;
    esac

    echo "${os}_${arch}"
}

install_terraform() {
    local version="$1"
    local platform=$(detect_platform)
    local filename="terraform_${version}_${platform}.zip"
    local url="https://releases.hashicorp.com/terraform/${version}/${filename}"
    local tmp_dir=$(mktemp -d)

    print_section "Installing Terraform $version"
    print_info "Platform: $platform"
    print_info "URL: $url"

    # Download
    print_info "Downloading..."
    if ! curl -fsSL -o "$tmp_dir/$filename" "$url"; then
        print_error "Failed to download Terraform"
        rm -rf "$tmp_dir"
        return 1
    fi
    print_success "Downloaded"

    # Verify zip file
    if ! unzip -t "$tmp_dir/$filename" &>/dev/null; then
        print_error "Downloaded file is not a valid zip"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Extract
    print_info "Extracting..."
    unzip -o "$tmp_dir/$filename" -d "$tmp_dir" >/dev/null

    if [ ! -f "$tmp_dir/terraform" ]; then
        print_error "terraform binary not found in archive"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Install
    print_info "Installing to $INSTALL_DIR..."
    sudo mv "$tmp_dir/terraform" "$INSTALL_DIR/terraform"
    sudo chmod +x "$INSTALL_DIR/terraform"

    # Cleanup
    rm -rf "$tmp_dir"

    print_success "Terraform $version installed to $INSTALL_DIR"
}

verify_installation() {
    print_section "Verification"

    if ! check_terraform_installed; then
        print_error "Terraform not found in PATH"
        return 1
    fi

    local version=$(get_installed_version)
    print_success "Installed: Terraform v$version"
    print_info "Path: $(which terraform)"

    # Show providers directory
    local providers_dir="$HOME/.terraform.d/plugins"
    if [ -d "$providers_dir" ]; then
        print_info "Providers: $providers_dir"
    fi

    # Test terraform
    print_info "Testing terraform..."
    if terraform -help &>/dev/null; then
        print_success "Terraform is working"
    else
        print_warning "Terraform help command failed"
    fi
}

show_version() {
    print_header "Terraform Version Information"

    if ! check_terraform_installed; then
        print_warning "Terraform is not installed"
        return 0
    fi

    terraform version

    echo ""
    print_info "Path: $(which terraform)"
}

uninstall_terraform() {
    print_header "Uninstalling Terraform"

    if ! check_terraform_installed; then
        print_warning "Terraform is not installed"
        return 0
    fi

    local tf_path=$(which terraform)
    print_info "Terraform path: $tf_path"

    if ! confirm "Remove Terraform?"; then
        print_info "Cancelled"
        return 0
    fi

    sudo rm -f "$tf_path"
    print_success "Terraform removed"

    # Ask about cleaning up terraform data
    local tf_data="$HOME/.terraform.d"
    if [ -d "$tf_data" ]; then
        print_info "Terraform data directory: $tf_data"
        if confirm "Remove Terraform data directory?"; then
            rm -rf "$tf_data"
            print_success "Terraform data removed"
        fi
    fi
}

install_dependencies() {
    print_section "Checking Dependencies"

    # Check for unzip
    if ! command -v unzip &>/dev/null; then
        print_info "Installing unzip..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get update -qq && sudo apt-get install -y unzip
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y unzip
        fi
    fi
    print_success "unzip available"

    # Check for curl
    if ! require_curl; then
        return 1
    fi

    # Check for jq (optional, for version parsing)
    if ! command -v jq &>/dev/null; then
        print_info "Installing jq..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get update -qq && sudo apt-get install -y jq
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y jq
        fi
    fi
    print_success "jq available"
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
        --uninstall)
            uninstall_terraform
            exit 0
            ;;
    esac

    print_header "Install Terraform"

    # Check dependencies
    install_dependencies

    # Determine version to install
    print_section "Version Selection"

    local current_version=$(get_installed_version)
    if [ -n "$current_version" ]; then
        print_info "Current version: $current_version"
    fi

    if [ -n "$TERRAFORM_VERSION" ] && [[ ! "$TERRAFORM_VERSION" =~ ^-- ]]; then
        local target_version="$TERRAFORM_VERSION"
        print_info "Target version: $target_version"
    else
        local target_version=$(get_latest_version)
        if [ -z "$target_version" ]; then
            return 1
        fi
        print_info "Latest version: $target_version"
    fi

    # Check if already installed
    if [ "$current_version" = "$target_version" ]; then
        print_success "Terraform $target_version is already installed"
        verify_installation
        return 0
    fi

    # Confirm upgrade
    if [ -n "$current_version" ]; then
        print_warning "This will upgrade Terraform from $current_version to $target_version"
        if ! confirm "Continue?"; then
            print_info "Cancelled"
            return 0
        fi
    fi

    # Install
    if ! install_terraform "$target_version"; then
        return 1
    fi

    # Verify
    verify_installation

    # Summary
    echo ""
    print_success "Terraform installation completed!"
    echo ""
    print_info "Quick start:"
    echo "  terraform init      # Initialize working directory"
    echo "  terraform plan      # Preview changes"
    echo "  terraform apply     # Apply changes"
    echo ""
    print_info "Documentation: https://www.terraform.io/docs"

    return 0
}

main "$@"
exit $?
