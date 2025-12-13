#!/bin/bash
# =============================================================================
# Delete Kind Cluster
# =============================================================================
#
# This script:
# 1. Checks if cluster exists
# 2. Prompts for confirmation
# 3. Deletes the kind cluster
#
# Usage:
#   ./delete-kind-cluster.sh [CLUSTER_NAME]
#   ./delete-kind-cluster.sh --all
#
# Examples:
#   ./delete-kind-cluster.sh
#   ./delete-kind-cluster.sh my-cluster
#   ./delete-kind-cluster.sh --all
#
# Flags:
#   --all, -a   Delete all kind clusters
#   --force, -f Skip confirmation prompt
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/k8s.sh"

# =============================================================================
# Configuration
# =============================================================================

CLUSTER_NAME=""
DELETE_ALL=false
FORCE=false

# =============================================================================
# Parse Arguments
# =============================================================================

parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --all|-a)
                DELETE_ALL=true
                shift
                ;;
            --force|-f)
                FORCE=true
                shift
                ;;
            --help|-h)
                echo "Delete Kind Cluster"
                echo ""
                echo "Usage: $0 [CLUSTER_NAME] [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --all, -a    Delete all kind clusters"
                echo "  --force, -f  Skip confirmation prompt"
                echo "  --help, -h   Show this help"
                exit 0
                ;;
            *)
                CLUSTER_NAME="$1"
                shift
                ;;
        esac
    done

    # Default cluster name
    if [ -z "$CLUSTER_NAME" ] && [ "$DELETE_ALL" = false ]; then
        CLUSTER_NAME="kind"
    fi
}

# =============================================================================
# Functions
# =============================================================================

delete_cluster() {
    local cluster_name="$1"

    if ! kind_cluster_exists "$cluster_name"; then
        print_warning "Cluster '$cluster_name' does not exist"
        return 0
    fi

    if [ "$FORCE" = false ]; then
        if ! confirm "Delete cluster '$cluster_name'?" "n"; then
            print_info "Cancelled"
            return 0
        fi
    fi

    if kind_delete_cluster "$cluster_name"; then
        print_success "Cluster '$cluster_name' deleted"
    else
        print_error "Failed to delete cluster '$cluster_name'"
        return 1
    fi
}

delete_all_clusters() {
    local clusters=$(kind get clusters 2>/dev/null)

    if [ -z "$clusters" ]; then
        print_info "No kind clusters found"
        return 0
    fi

    local count=$(echo "$clusters" | wc -l)
    print_warning "Found $count cluster(s) to delete:"
    echo "$clusters" | sed 's/^/  - /'
    echo ""

    if [ "$FORCE" = false ]; then
        if ! confirm "Delete ALL $count clusters?" "n"; then
            print_info "Cancelled"
            return 0
        fi
    fi

    for cluster in $clusters; do
        print_info "Deleting '$cluster'..."
        if kind_delete_cluster "$cluster"; then
            print_success "Deleted '$cluster'"
        else
            print_error "Failed to delete '$cluster'"
        fi
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    print_header "Delete Kind Cluster"

    # Check prerequisites
    if ! require_kind; then
        return 1
    fi

    # List current clusters
    local clusters=$(kind get clusters 2>/dev/null)

    if [ -z "$clusters" ]; then
        print_info "No kind clusters found"
        return 0
    fi

    print_section "Current Clusters"
    echo "$clusters" | sed 's/^/  - /'
    echo ""

    # Delete
    if [ "$DELETE_ALL" = true ]; then
        delete_all_clusters
    else
        delete_cluster "$CLUSTER_NAME"
    fi

    # Show remaining clusters
    local remaining=$(kind get clusters 2>/dev/null)
    if [ -n "$remaining" ]; then
        echo ""
        print_info "Remaining clusters:"
        echo "$remaining" | sed 's/^/  - /'
    fi

    return 0
}

main "$@"
exit $?
