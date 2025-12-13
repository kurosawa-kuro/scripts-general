#!/bin/bash
# =============================================================================
# Setup EKS Kubeconfig
# =============================================================================
#
# This script:
# 1. Verifies EKS cluster exists
# 2. Updates kubeconfig for the cluster
# 3. Sets the kubectl context
# 4. Verifies connection
#
# Usage:
#   ./setup-eks-kubeconfig.sh [CLUSTER_NAME]
#
# Examples:
#   ./setup-eks-kubeconfig.sh my-cluster
#   AWS_REGION=us-east-1 ./setup-eks-kubeconfig.sh prod-cluster
#   AWS_PROFILE=work ./setup-eks-kubeconfig.sh dev-cluster
#
# Environment Variables:
#   AWS_REGION  - AWS region (default: ap-northeast-1)
#   AWS_PROFILE - AWS profile to use
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"
source "$SCRIPT_DIR/../lib/k8s.sh"

# =============================================================================
# Configuration
# =============================================================================

CLUSTER_NAME="${1}"
REGION="$(aws_get_region)"
AWS_PROFILE_NAME="${AWS_PROFILE:-}"

# =============================================================================
# Functions
# =============================================================================

list_eks_clusters() {
    print_section "Available EKS Clusters"

    local clusters=$(eks_list_clusters "$REGION")

    if [ -z "$clusters" ]; then
        print_info "No EKS clusters found in $REGION"
        return 0
    fi

    echo "$clusters" | tr '\t' '\n' | sed 's/^/  - /'
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Validate arguments
    if [ -z "$CLUSTER_NAME" ]; then
        print_header "Setup EKS Kubeconfig"

        if ! require_aws_cli; then
            return 1
        fi

        list_eks_clusters

        echo ""
        print_error "Cluster name is required"
        echo ""
        echo "Usage: $0 [CLUSTER_NAME]"
        echo "Example: $0 my-cluster"
        exit 1
    fi

    print_header "Setup EKS Kubeconfig: $CLUSTER_NAME"

    # Check prerequisites
    print_section "Prerequisites"

    if ! require_aws_cli; then
        return 1
    fi
    print_success "AWS CLI is configured"

    if ! require_kubectl; then
        return 1
    fi
    print_success "kubectl is installed"

    # Show configuration
    print_section "Configuration"
    print_info "Cluster: $CLUSTER_NAME"
    print_info "Region: $REGION"
    if [ -n "$AWS_PROFILE_NAME" ]; then
        print_info "Profile: $AWS_PROFILE_NAME"
    fi

    # Step 1: Check if cluster exists
    print_section "Cluster Verification"

    print_info "Checking if cluster exists..."
    if ! eks_cluster_exists "$CLUSTER_NAME" "$REGION"; then
        print_error "Cluster '$CLUSTER_NAME' not found in $REGION"
        echo ""
        list_eks_clusters
        return 1
    fi
    print_success "Cluster '$CLUSTER_NAME' exists"

    # Get cluster info
    local cluster_info=$(eks_get_cluster_info "$CLUSTER_NAME" "$REGION")
    local cluster_status=$(json_get "$cluster_info" '.cluster.status')
    local cluster_version=$(json_get "$cluster_info" '.cluster.version')
    local cluster_endpoint=$(json_get "$cluster_info" '.cluster.endpoint')

    print_info "Status: $cluster_status"
    print_info "Version: $cluster_version"

    if [ "$cluster_status" != "ACTIVE" ]; then
        print_warning "Cluster is not ACTIVE (status: $cluster_status)"
    fi

    # Step 2: Update kubeconfig
    print_section "Kubeconfig Update"

    print_info "Updating kubeconfig..."
    if eks_update_kubeconfig "$CLUSTER_NAME" "$REGION" "$AWS_PROFILE_NAME"; then
        print_success "Kubeconfig updated"
    else
        print_error "Failed to update kubeconfig"
        return 1
    fi

    # Step 3: Verify connection
    print_section "Connection Verification"

    print_info "Testing connection..."
    if k8s_check_connection; then
        print_success "Connected to cluster"
    else
        print_error "Cannot connect to cluster"
        print_info "Check your network and AWS credentials"
        return 1
    fi

    # Show nodes
    print_info "Nodes:"
    k8s_get_nodes | sed 's/^/  /' || print_warning "Could not get nodes"

    # Summary
    echo ""
    print_success "EKS kubeconfig configured successfully!"

    echo ""
    print_section "Connection Information"
    echo ""
    echo "  Cluster:  $CLUSTER_NAME"
    echo "  Region:   $REGION"
    echo "  Version:  $cluster_version"
    echo "  Endpoint: ${cluster_endpoint:0:60}..."
    echo "  Context:  $(k8s_get_current_context)"
    echo ""
    print_info "Useful commands:"
    print_info "  Get nodes:      kubectl get nodes"
    print_info "  Get pods:       kubectl get pods -A"
    print_info "  Get services:   kubectl get svc -A"
    print_info "  Switch context: kubectl config use-context <context>"

    return 0
}

main "$@"
exit $?
