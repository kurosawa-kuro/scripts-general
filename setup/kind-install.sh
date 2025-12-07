#!/bin/bash
# =============================================================================
# kind Installation
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"

print_usage() {
    echo "kind Installation (Kubernetes IN Docker)"
    echo ""
    echo "Usage:"
    echo "  $0                # Install kind"
    echo "  $0 --version      # Show installed version"
    echo "  $0 --help         # Show this help"
}

get_latest_version() {
    curl -sL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r '.tag_name'
}

install_kind() {
    print_header "Install kind"

    if command -v kind &>/dev/null; then
        local version=$(kind version | awk '{print $2}')
        print_info "kind already installed: $version"

        if ! confirm "Reinstall?"; then
            return 0
        fi
    fi

    local target_version=$(get_latest_version)
    print_info "Target version: $target_version"

    print_section "Downloading"

    local platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    [ "$arch" = "x86_64" ] && arch="amd64"
    [ "$arch" = "aarch64" ] && arch="arm64"

    local url="https://kind.sigs.k8s.io/dl/${target_version}/kind-${platform}-${arch}"

    curl -fsSLo kind "$url"

    print_section "Installing"
    chmod +x kind
    sudo mv kind /usr/local/bin/

    print_success "kind installed"

    print_section "Verification"
    kind version

    echo ""
    print_info "Create cluster: make kind-create"
}

case "${1:-}" in
    --help|-h) print_usage; exit 0 ;;
    --version|-v) kind version 2>/dev/null || echo "Not installed"; exit 0 ;;
esac

install_kind
