#!/bin/bash
# =============================================================================
# Rust Installation (rustup)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"

print_usage() {
    echo "Rust Installation (rustup)"
    echo ""
    echo "Usage:"
    echo "  $0                # Install Rust"
    echo "  $0 --version      # Show installed version"
    echo "  $0 --uninstall    # Uninstall Rust"
    echo "  $0 --help         # Show this help"
}

install_rust() {
    print_header "Install Rust"

    if command -v rustc &>/dev/null; then
        local version=$(rustc --version | awk '{print $2}')
        print_info "Rust already installed: v$version"

        if ! confirm "Update?"; then
            return 0
        fi

        print_section "Updating"
        rustup update
        print_success "Rust updated"
        return 0
    fi

    print_section "Installing rustup"

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Source cargo env
    source "$HOME/.cargo/env"

    print_success "Rust installed"

    print_section "Verification"
    rustc --version
    cargo --version

    echo ""
    print_info "Restart shell or run: source ~/.cargo/env"
}

case "${1:-}" in
    --help|-h) print_usage; exit 0 ;;
    --version|-v)
        rustc --version 2>/dev/null || echo "Not installed"
        cargo --version 2>/dev/null
        exit 0
        ;;
    --uninstall)
        rustup self uninstall
        exit 0
        ;;
esac

install_rust
