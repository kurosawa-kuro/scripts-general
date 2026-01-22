#!/bin/bash
# =============================================================================
# Docker Buildx Setup
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"

BUILDER_NAME="${1:-multiarch}"

print_usage() {
    echo "Docker Buildx Setup"
    echo ""
    echo "Usage:"
    echo "  $0 [BUILDER_NAME]    # Setup buildx builder"
    echo "  $0 --list            # List builders"
    echo "  $0 --version         # Show version"
    echo "  $0 --help            # Show this help"
}

setup_buildx() {
    print_header "Docker Buildx Setup"

    if ! command -v docker &>/dev/null; then
        print_error "Docker not installed"
        return 1
    fi

    # Check buildx
    if ! docker buildx version &>/dev/null; then
        print_error "Docker buildx not available"
        print_info "Update Docker to latest version"
        return 1
    fi

    print_info "Buildx version: $(docker buildx version | head -1)"

    print_section "Creating Builder: $BUILDER_NAME"

    # Check if builder exists
    if docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
        print_info "Builder '$BUILDER_NAME' already exists"
    else
        docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
        print_success "Builder created"
    fi

    # Use the builder
    docker buildx use "$BUILDER_NAME"
    print_success "Using builder: $BUILDER_NAME"

    print_section "Supported Platforms"
    docker buildx inspect --bootstrap | grep "Platforms:" | head -1

    echo ""
    print_info "Build example:"
    echo "  docker buildx build --platform linux/amd64,linux/arm64 -t myimage:latest --push ."
}

case "${1:-}" in
    --help|-h) print_usage; exit 0 ;;
    --version|-v) docker buildx version; exit 0 ;;
    --list|-l) docker buildx ls; exit 0 ;;
esac

setup_buildx
