#!/bin/bash
# =============================================================================
# Helm Installation
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"

print_usage() {
    echo "Helm Installation"
    echo ""
    echo "Usage:"
    echo "  $0                # Install Helm"
    echo "  $0 --version      # Show installed version"
    echo "  $0 --help         # Show this help"
}

install_helm() {
    print_header "Install Helm"

    if command -v helm &>/dev/null; then
        local version=$(helm version --short 2>/dev/null)
        print_info "Helm already installed: $version"

        if ! confirm "Reinstall?"; then
            return 0
        fi
    fi

    print_section "Installing"

    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    print_success "Helm installed"

    print_section "Verification"
    helm version

    echo ""
    print_info "Add repos: make helm-repo --common"
}

case "${1:-}" in
    --help|-h) print_usage; exit 0 ;;
    --version|-v) helm version --short 2>/dev/null || echo "Not installed"; exit 0 ;;
esac

install_helm
