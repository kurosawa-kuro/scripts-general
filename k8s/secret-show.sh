#!/bin/bash
# =============================================================================
# Show Kubernetes Secret
# =============================================================================
# Purpose: Display Kubernetes secret details and values
# Usage:
#   ./secret-show.sh NAME [-n NAMESPACE]
#   ./secret-show.sh NAME --decode
#   ./secret-show.sh --list
#   ./secret-show.sh --help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/k8s.sh"

# =============================================================================
# Configuration
# =============================================================================

SECRET_NAME=""
NAMESPACE="default"
DECODE_VALUES=false
OUTPUT_KEY=""

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Show Kubernetes Secret"
    echo ""
    echo "Usage:"
    echo "  $0 NAME [-n NAMESPACE]      # Show secret metadata"
    echo "  $0 NAME --decode            # Show decoded values"
    echo "  $0 NAME --key KEY           # Show specific key value"
    echo "  $0 --list [-n NAMESPACE]    # List all secrets"
    echo "  $0 --help                   # Show this help"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NS   Target namespace (default: default)"
    echo "  --decode, -d         Decode and show all values"
    echo "  --key KEY            Show specific key only"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --decode|-d)
                DECODE_VALUES=true
                shift
                ;;
            --key|-k)
                OUTPUT_KEY="$2"
                DECODE_VALUES=true
                shift 2
                ;;
            --list|-l)
                list_secrets
                exit 0
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                if [ -z "$SECRET_NAME" ]; then
                    SECRET_NAME="$1"
                fi
                shift
                ;;
        esac
    done
}

list_secrets() {
    print_header "Kubernetes Secrets"

    local ns="${NAMESPACE:-}"

    if [ -n "$ns" ] && [ "$ns" != "default" ]; then
        print_info "Namespace: $ns"
        echo ""
        kubectl get secrets -n "$ns" 2>/dev/null
    else
        print_info "All namespaces"
        echo ""
        kubectl get secrets -A 2>/dev/null
    fi
}

show_secret() {
    local name="$1"

    # Check if secret exists
    if ! k8s_secret_exists "$name" "$NAMESPACE"; then
        print_error "Secret '$name' not found in namespace '$NAMESPACE'"
        return 1
    fi

    print_header "Kubernetes Secret: $name"

    # Get secret info
    local secret_json=$(k8s_secret_get "$name" "$NAMESPACE")

    local secret_type=$(echo "$secret_json" | jq -r '.type')
    local created=$(echo "$secret_json" | jq -r '.metadata.creationTimestamp')

    print_section "Metadata"
    echo "  Name:      $name"
    echo "  Namespace: $NAMESPACE"
    echo "  Type:      $secret_type"
    echo "  Created:   $created"

    # Get data keys
    local keys=$(echo "$secret_json" | jq -r '.data | keys[]' 2>/dev/null)

    if [ -z "$keys" ]; then
        print_info "Secret has no data"
        return 0
    fi

    print_section "Data Keys"
    echo "$keys" | while read -r key; do
        local size=$(echo "$secret_json" | jq -r ".data[\"$key\"]" | wc -c)
        printf "  %-30s %d bytes\n" "$key" "$size"
    done

    # Decode values if requested
    if [ "$DECODE_VALUES" = true ]; then
        print_section "Decoded Values"

        if [ -n "$OUTPUT_KEY" ]; then
            # Show specific key
            local value=$(echo "$secret_json" | jq -r ".data[\"$OUTPUT_KEY\"]" 2>/dev/null)
            if [ -z "$value" ] || [ "$value" = "null" ]; then
                print_error "Key '$OUTPUT_KEY' not found"
                return 1
            fi
            echo "$value" | base64 -d
            echo ""
        else
            # Show all keys
            echo "$keys" | while read -r key; do
                local value=$(echo "$secret_json" | jq -r ".data[\"$key\"]" 2>/dev/null | base64 -d 2>/dev/null)
                echo -e "  ${CYAN}$key:${NC}"

                # Check if value looks like binary
                if echo "$value" | grep -qP '[^\x20-\x7E\n\t]'; then
                    echo "    <binary data>"
                else
                    # Truncate long values
                    if [ ${#value} -gt 200 ]; then
                        echo "    ${value:0:200}..."
                    else
                        echo "$value" | sed 's/^/    /'
                    fi
                fi
                echo ""
            done
        fi
    else
        echo ""
        print_info "Use --decode to show actual values"
    fi

    # Labels and annotations
    local labels=$(echo "$secret_json" | jq -r '.metadata.labels // {} | to_entries | .[] | "  \(.key)=\(.value)"')
    if [ -n "$labels" ]; then
        print_section "Labels"
        echo "$labels"
    fi

    echo ""
    print_info "Commands:"
    echo "  Decode: $0 $name --decode -n $NAMESPACE"
    echo "  Delete: kubectl delete secret $name -n $NAMESPACE"
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

    if [ -z "$SECRET_NAME" ]; then
        list_secrets
        exit 0
    fi

    show_secret "$SECRET_NAME"
}

main "$@"
exit $?
