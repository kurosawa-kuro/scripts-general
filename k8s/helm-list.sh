#!/bin/bash
# =============================================================================
# List Helm Releases
# =============================================================================
# Purpose: List and show details of Helm releases
# Usage:
#   ./helm-list.sh                     # List all releases
#   ./helm-list.sh -n NAMESPACE        # List in namespace
#   ./helm-list.sh RELEASE             # Show release details
#   ./helm-list.sh --help
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
SHOW_VALUES=false
SHOW_HISTORY=false

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "List Helm Releases"
    echo ""
    echo "Usage:"
    echo "  $0                          # List all releases"
    echo "  $0 -n NAMESPACE             # List in namespace"
    echo "  $0 RELEASE [-n NS]          # Show release details"
    echo "  $0 RELEASE --values         # Show release values"
    echo "  $0 RELEASE --history        # Show release history"
    echo "  $0 --help                   # Show this help"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --values|-v)
                SHOW_VALUES=true
                shift
                ;;
            --history)
                SHOW_HISTORY=true
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

list_releases() {
    print_header "Helm Releases"

    local releases
    if [ -n "$NAMESPACE" ]; then
        print_info "Namespace: $NAMESPACE"
        releases=$(helm list -n "$NAMESPACE" 2>/dev/null)
    else
        print_info "All namespaces"
        releases=$(helm list -A 2>/dev/null)
    fi

    if [ -z "$releases" ] || [ "$(echo "$releases" | wc -l)" -le 1 ]; then
        print_info "No Helm releases found"
        return 0
    fi

    echo ""
    echo "$releases"

    local count=$(echo "$releases" | tail -n +2 | wc -l)
    echo ""
    print_info "Total: $count releases"
}

show_release() {
    local name="$1"
    local ns="${NAMESPACE:-default}"

    # Try to find the release
    local found_ns=""
    if [ -z "$NAMESPACE" ]; then
        # Search all namespaces
        found_ns=$(helm list -A 2>/dev/null | grep "^${name}\s" | awk '{print $2}' | head -1)
        if [ -n "$found_ns" ]; then
            ns="$found_ns"
        fi
    fi

    if ! helm_release_exists "$name" "$ns"; then
        print_error "Release '$name' not found"
        return 1
    fi

    print_header "Helm Release: $name"

    # Show values
    if [ "$SHOW_VALUES" = true ]; then
        print_section "Values"
        helm get values "$name" -n "$ns" 2>/dev/null
        return 0
    fi

    # Show history
    if [ "$SHOW_HISTORY" = true ]; then
        print_section "History"
        helm history "$name" -n "$ns" 2>/dev/null
        return 0
    fi

    # Show status
    print_section "Status"
    helm status "$name" -n "$ns" 2>/dev/null

    # Show resources
    echo ""
    print_section "Resources"
    helm get manifest "$name" -n "$ns" 2>/dev/null | grep -E "^kind:|^  name:" | paste - - | head -20

    echo ""
    print_info "Commands:"
    echo "  Values:   make helm-values RELEASE=$name NAMESPACE=$ns"
    echo "  History:  make helm-history RELEASE=$name NAMESPACE=$ns"
    echo "  Upgrade:  make helm-upgrade RELEASE=$name CHART=... NAMESPACE=$ns"
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

    if [ -n "$RELEASE_NAME" ]; then
        show_release "$RELEASE_NAME"
    else
        list_releases
    fi
}

main "$@"
exit $?
