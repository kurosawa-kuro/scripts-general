#!/bin/bash
# =============================================================================
# kubectl Installation
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"

VERSION="${1:-}"

print_usage() {
    echo "kubectl Installation"
    echo ""
    echo "Usage:"
    echo "  $0 [VERSION]      # Install kubectl"
    echo "  $0 --version      # Show installed version"
    echo "  $0 --help         # Show this help"
}

get_latest_version() {
    curl -sL https://dl.k8s.io/release/stable.txt
}

install_kubectl() {
    print_header "Install kubectl"

    local target_version="$VERSION"
    if [ -z "$target_version" ]; then
        target_version=$(get_latest_version)
    fi

    print_info "Target version: $target_version"

    if command -v kubectl &>/dev/null; then
        local current=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion')
        print_info "Current version: $current"

        if [ "$current" = "$target_version" ]; then
            print_success "Already up to date"
            return 0
        fi
    fi

    print_section "Downloading"

    local platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    [ "$arch" = "x86_64" ] && arch="amd64"
    [ "$arch" = "aarch64" ] && arch="arm64"

    local url="https://dl.k8s.io/release/${target_version}/bin/${platform}/${arch}/kubectl"

    curl -fsSLO "$url"
    curl -fsSLO "$url.sha256"

    print_section "Verifying"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    print_success "Checksum verified"

    print_section "Installing"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    rm -f kubectl.sha256

    print_success "kubectl installed"

    print_section "Verification"
    kubectl version --client
}

case "${1:-}" in
    --help|-h) print_usage; exit 0 ;;
    --version|-v) kubectl version --client 2>/dev/null || echo "Not installed"; exit 0 ;;
esac

install_kubectl
