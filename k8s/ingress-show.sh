#!/bin/bash
# =============================================================================
# Show Kubernetes Ingress
# =============================================================================
# Purpose: Display Ingress details and routing information
# Usage:
#   ./ingress-show.sh [NAME] [-n NAMESPACE]
#   ./ingress-show.sh --list
#   ./ingress-show.sh --help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/k8s.sh"

# =============================================================================
# Configuration
# =============================================================================

INGRESS_NAME=""
NAMESPACE=""
SHOW_YAML=false

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Show Kubernetes Ingress"
    echo ""
    echo "Usage:"
    echo "  $0 [NAME] [-n NAMESPACE]    # Show ingress details"
    echo "  $0 --list [-n NAMESPACE]    # List all ingresses"
    echo "  $0 NAME --yaml              # Show YAML"
    echo "  $0 --help                   # Show this help"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NS   Target namespace"
    echo "  --yaml               Show full YAML"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --yaml|-y)
                SHOW_YAML=true
                shift
                ;;
            --list|-l)
                list_ingresses
                exit 0
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                if [ -z "$INGRESS_NAME" ]; then
                    INGRESS_NAME="$1"
                fi
                shift
                ;;
        esac
    done
}

list_ingresses() {
    print_header "Kubernetes Ingresses"

    if [ -n "$NAMESPACE" ]; then
        print_info "Namespace: $NAMESPACE"
        echo ""
        kubectl get ingress -n "$NAMESPACE" -o wide 2>/dev/null
    else
        print_info "All namespaces"
        echo ""
        kubectl get ingress -A -o wide 2>/dev/null
    fi

    # Count
    local count
    if [ -n "$NAMESPACE" ]; then
        count=$(kubectl get ingress -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    else
        count=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
    fi

    echo ""
    print_info "Total: $count ingress(es)"
}

show_ingress() {
    local name="$1"
    local ns="${NAMESPACE:-default}"

    # Try to find the ingress
    if [ -z "$NAMESPACE" ]; then
        local found_ns=$(kubectl get ingress -A --no-headers 2>/dev/null | grep "^\S*\s*${name}\s" | awk '{print $1}' | head -1)
        if [ -n "$found_ns" ]; then
            ns="$found_ns"
        fi
    fi

    # Check if ingress exists
    if ! k8s_ingress_exists "$name" "$ns"; then
        print_error "Ingress '$name' not found"
        return 1
    fi

    print_header "Kubernetes Ingress: $name"

    # Show YAML if requested
    if [ "$SHOW_YAML" = true ]; then
        kubectl get ingress "$name" -n "$ns" -o yaml
        return 0
    fi

    # Get ingress JSON
    local ingress_json=$(k8s_ingress_get "$name" "$ns")

    local ingress_class=$(echo "$ingress_json" | jq -r '.spec.ingressClassName // .metadata.annotations["kubernetes.io/ingress.class"] // "N/A"')
    local created=$(echo "$ingress_json" | jq -r '.metadata.creationTimestamp')

    print_section "Metadata"
    echo "  Name:      $name"
    echo "  Namespace: $ns"
    echo "  Class:     $ingress_class"
    echo "  Created:   $created"

    # TLS
    local tls=$(echo "$ingress_json" | jq -r '.spec.tls // []')
    if [ "$tls" != "[]" ]; then
        print_section "TLS Configuration"
        echo "$tls" | jq -r '.[] | "  Host: \(.hosts[0] // "*")\n  Secret: \(.secretName // "N/A")"'
    fi

    # Rules
    print_section "Routing Rules"
    local rules=$(echo "$ingress_json" | jq -r '.spec.rules // []')

    echo "$rules" | jq -r '.[] |
        "  Host: \(.host // "*")" as $host |
        .http.paths[] |
        "  \($host)\n    Path: \(.path) (\(.pathType))\n    Backend: \(.backend.service.name):\(.backend.service.port.number // .backend.service.port.name)"
    '

    # Get address
    local address=$(echo "$ingress_json" | jq -r '.status.loadBalancer.ingress[0].ip // .status.loadBalancer.ingress[0].hostname // "Pending"')

    print_section "Status"
    echo "  Address: $address"

    # Events
    print_section "Recent Events"
    kubectl get events -n "$ns" --field-selector "involvedObject.name=$name,involvedObject.kind=Ingress" --sort-by='.lastTimestamp' 2>/dev/null | tail -5

    echo ""
    print_info "Commands:"
    echo "  Describe: kubectl describe ingress $name -n $ns"
    echo "  Edit:     kubectl edit ingress $name -n $ns"
    echo "  Delete:   kubectl delete ingress $name -n $ns"
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    # Check prerequisites
    if ! require_kubectl; then
        return 1
    fi

    if [ -z "$INGRESS_NAME" ]; then
        list_ingresses
        exit 0
    fi

    show_ingress "$INGRESS_NAME"
}

main "$@"
exit $?
