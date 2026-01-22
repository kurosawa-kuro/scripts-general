#!/bin/bash
# =============================================================================
# Uninstall Helm Release
# =============================================================================
# Purpose: Uninstall Helm releases
# Usage:
#   ./helm-uninstall.sh RELEASE [-n NAMESPACE]
#   ./helm-uninstall.sh --all [-n NAMESPACE]
#   ./helm-uninstall.sh --help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/k8s.sh"

# =============================================================================
# Configuration
# =============================================================================

RELEASE_NAME=""
NAMESPACE=""
UNINSTALL_ALL=false
FORCE=false

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Uninstall Helm Release"
    echo ""
    echo "Usage:"
    echo "  $0 RELEASE [-n NAMESPACE]     # Uninstall release"
    echo "  $0 --all [-n NAMESPACE]       # Uninstall all releases"
    echo "  $0 --help                     # Show this help"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NS   Target namespace"
    echo "  --all                Uninstall all releases"
    echo "  --force              Skip confirmation"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --all|-a)
                UNINSTALL_ALL=true
                shift
                ;;
            --force|-f)
                FORCE=true
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                if [ -z "$RELEASE_NAME" ]; then
                    RELEASE_NAME="$1"
                fi
                shift
                ;;
        esac
    done
}

uninstall_release() {
    local name="$1"
    local ns="${NAMESPACE:-default}"

    # Try to find the release
    if [ -z "$NAMESPACE" ]; then
        local found_ns=$(helm list -A 2>/dev/null | grep "^${name}\s" | awk '{print $2}' | head -1)
        if [ -n "$found_ns" ]; then
            ns="$found_ns"
        fi
    fi

    if ! helm_release_exists "$name" "$ns"; then
        print_warning "Release '$name' not found"
        return 0
    fi

    print_info "Release: $name"
    print_info "Namespace: $ns"

    # Show current status
    local status=$(helm status "$name" -n "$ns" 2>/dev/null | grep "STATUS:" | awk '{print $2}')
    print_info "Status: $status"

    if [ "$FORCE" = false ]; then
        if ! confirm "Uninstall release '$name'?"; then
            print_info "Cancelled"
            return 0
        fi
    fi

    helm_uninstall "$name" "$ns"
    print_success "Release '$name' uninstalled"
}

uninstall_all_releases() {
    print_header "Uninstall All Helm Releases"

    local releases
    if [ -n "$NAMESPACE" ]; then
        print_info "Namespace: $NAMESPACE"
        releases=$(helm list -n "$NAMESPACE" -q 2>/dev/null)
    else
        print_warning "This will uninstall ALL releases in ALL namespaces"
        releases=$(helm list -A -q 2>/dev/null)
    fi

    if [ -z "$releases" ]; then
        print_info "No releases found"
        return 0
    fi

    local count=$(echo "$releases" | wc -l)
    print_warning "Found $count release(s) to uninstall"

    echo ""
    echo "$releases" | while read -r name; do
        echo "  - $name"
    done
    echo ""

    if [ "$FORCE" = false ]; then
        if ! confirm "Uninstall all $count releases?"; then
            print_info "Cancelled"
            return 0
        fi
    fi

    echo "$releases" | while read -r name; do
        local ns="$NAMESPACE"
        if [ -z "$ns" ]; then
            ns=$(helm list -A 2>/dev/null | grep "^${name}\s" | awk '{print $2}' | head -1)
        fi

        print_info "Uninstalling: $name (namespace: $ns)"
        helm uninstall "$name" -n "$ns" 2>/dev/null || print_warning "Failed to uninstall $name"
    done

    print_success "All releases uninstalled"
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    # Check prerequisites
    if ! require_helm; then
        return 1
    fi

    if [ "$UNINSTALL_ALL" = true ]; then
        uninstall_all_releases
        exit $?
    fi

    if [ -z "$RELEASE_NAME" ]; then
        print_error "Release name required"
        echo ""
        print_usage
        exit 1
    fi

    print_header "Uninstall Helm Release"
    uninstall_release "$RELEASE_NAME"
}

main "$@"
exit $?
