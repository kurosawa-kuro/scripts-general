#!/bin/bash
# =============================================================================
# Setup Kind Cluster
# =============================================================================
#
# This script:
# 1. Creates a kind (Kubernetes in Docker) cluster
# 2. Configures kubectl context
# 3. Verifies cluster is ready
#
# Usage:
#   ./setup-kind-cluster.sh [CLUSTER_NAME]
#
# Examples:
#   ./setup-kind-cluster.sh
#   ./setup-kind-cluster.sh my-cluster
#   KIND_CONFIG=./kind-config.yaml ./setup-kind-cluster.sh dev-cluster
#
# Environment Variables:
#   KIND_CONFIG - Path to kind config file (optional)
#   KIND_IMAGE  - Kind node image (optional, e.g., kindest/node:v1.28.0)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/k8s.sh"

# =============================================================================
# Configuration
# =============================================================================

CLUSTER_NAME="${1:-kind}"
KIND_CONFIG="${KIND_CONFIG:-}"
KIND_IMAGE="${KIND_IMAGE:-}"

# =============================================================================
# Main
# =============================================================================

main() {
    local exit_code=0

    print_header "Setting Up Kind Cluster: $CLUSTER_NAME"

    # Check prerequisites
    print_section "Prerequisites"

    if ! command -v docker &> /dev/null; then
        print_error "docker is not installed"
        print_info "Install: https://docs.docker.com/get-docker/"
        return 1
    fi
    print_success "docker is installed"

    # Check if docker daemon is running
    if ! docker info &>/dev/null; then
        print_error "Docker daemon is not running"
        print_info "Start Docker and try again"
        return 1
    fi
    print_success "Docker daemon is running"

    if ! require_kind; then
        return 1
    fi
    print_success "kind is installed: $(kind version)"

    if ! require_kubectl; then
        return 1
    fi
    print_success "kubectl is installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client -o yaml | grep gitVersion | head -1)"

    # Step 1: Check if cluster exists
    print_section "Cluster Setup"

    if kind_cluster_exists "$CLUSTER_NAME"; then
        print_success "Cluster '$CLUSTER_NAME' already exists"

        # Ensure context is set
        local context_name="kind-$CLUSTER_NAME"
        if k8s_context_exists "$context_name"; then
            k8s_set_context "$context_name"
            print_success "Context set to: $context_name"
        fi
    else
        print_info "Creating cluster '$CLUSTER_NAME'..."

        # Create cluster
        if kind_create_cluster "$CLUSTER_NAME" "$KIND_CONFIG" "$KIND_IMAGE"; then
            print_success "Cluster created successfully"
        else
            print_error "Failed to create cluster"
            return 1
        fi
    fi

    # Step 2: Wait for nodes to be ready
    print_section "Cluster Verification"

    if ! k8s_check_connection; then
        print_error "Cannot connect to cluster"
        return 1
    fi
    print_success "Connected to cluster"

    # Wait for nodes
    k8s_wait_nodes_ready 60

    # Show cluster info
    print_section "Cluster Information"
    print_info "Nodes:"
    k8s_get_nodes | sed 's/^/  /'

    echo ""
    print_info "Cluster Context: kind-$CLUSTER_NAME"

    # Summary
    echo ""
    print_success "Kind cluster '$CLUSTER_NAME' is ready!"

    echo ""
    print_info "Useful commands:"
    print_info "  Get nodes:    kubectl get nodes"
    print_info "  Get pods:     kubectl get pods -A"
    print_info "  Load image:   kind load docker-image my-image:tag --name $CLUSTER_NAME"
    print_info "  Delete:       ./delete-kind-cluster.sh $CLUSTER_NAME"

    return $exit_code
}

main "$@"
exit $?
