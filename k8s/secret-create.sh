#!/bin/bash
# =============================================================================
# Create Kubernetes Secret
# =============================================================================
# Purpose: Create Kubernetes secrets (generic, TLS, docker-registry)
# Usage:
#   ./secret-create.sh NAME KEY=VALUE [-n NAMESPACE]
#   ./secret-create.sh NAME --from-file FILE
#   ./secret-create.sh NAME --tls CERT KEY
#   ./secret-create.sh --help
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
SECRET_TYPE="generic"
LITERALS=()
FROM_FILE=""
TLS_CERT=""
TLS_KEY=""
DOCKER_SERVER=""
DOCKER_USER=""
DOCKER_PASS=""

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Create Kubernetes Secret"
    echo ""
    echo "Usage:"
    echo "  $0 NAME KEY=VALUE [KEY=VALUE...]   # Generic secret"
    echo "  $0 NAME --from-file FILE           # From file"
    echo "  $0 NAME --tls CERT_FILE KEY_FILE   # TLS secret"
    echo "  $0 NAME --docker SERVER USER PASS  # Docker registry"
    echo "  $0 --list [-n NAMESPACE]           # List secrets"
    echo "  $0 --help                          # Show this help"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NS   Target namespace (default: default)"
    echo "  --from-file FILE     Create from file"
    echo "  --tls CERT KEY       Create TLS secret"
    echo "  --docker S U P       Create docker-registry secret"
    echo ""
    echo "Examples:"
    echo "  $0 my-secret username=admin password=secret123"
    echo "  $0 app-config --from-file ./config.yaml"
    echo "  $0 tls-cert --tls ./cert.pem ./key.pem"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --from-file)
                FROM_FILE="$2"
                shift 2
                ;;
            --tls)
                SECRET_TYPE="tls"
                TLS_CERT="$2"
                TLS_KEY="$3"
                shift 3
                ;;
            --docker)
                SECRET_TYPE="docker"
                DOCKER_SERVER="$2"
                DOCKER_USER="$3"
                DOCKER_PASS="$4"
                shift 4
                ;;
            --list|-l)
                list_secrets
                exit 0
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *=*)
                LITERALS+=("$1")
                shift
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

    if [ -n "$NAMESPACE" ] && [ "$NAMESPACE" != "default" ]; then
        print_info "Namespace: $NAMESPACE"
        k8s_secret_list "$NAMESPACE"
    else
        print_info "All namespaces"
        k8s_secret_list
    fi
}

create_generic_secret() {
    print_section "Creating Generic Secret"

    if [ ${#LITERALS[@]} -eq 0 ] && [ -z "$FROM_FILE" ]; then
        print_error "At least one KEY=VALUE or --from-file required"
        return 1
    fi

    local cmd="kubectl create secret generic $SECRET_NAME -n $NAMESPACE"

    # Add literals
    for lit in "${LITERALS[@]}"; do
        cmd="$cmd --from-literal=$lit"
    done

    # Add from file
    if [ -n "$FROM_FILE" ]; then
        if [ ! -f "$FROM_FILE" ]; then
            print_error "File not found: $FROM_FILE"
            return 1
        fi
        cmd="$cmd --from-file=$FROM_FILE"
    fi

    eval "$cmd"
    print_success "Secret created: $SECRET_NAME"
}

create_tls_secret() {
    print_section "Creating TLS Secret"

    if [ ! -f "$TLS_CERT" ]; then
        print_error "Certificate file not found: $TLS_CERT"
        return 1
    fi

    if [ ! -f "$TLS_KEY" ]; then
        print_error "Key file not found: $TLS_KEY"
        return 1
    fi

    kubectl create secret tls "$SECRET_NAME" -n "$NAMESPACE" \
        --cert="$TLS_CERT" --key="$TLS_KEY"

    print_success "TLS secret created: $SECRET_NAME"
}

create_docker_secret() {
    print_section "Creating Docker Registry Secret"

    if [ -z "$DOCKER_SERVER" ] || [ -z "$DOCKER_USER" ] || [ -z "$DOCKER_PASS" ]; then
        print_error "Docker server, username, and password required"
        return 1
    fi

    kubectl create secret docker-registry "$SECRET_NAME" -n "$NAMESPACE" \
        --docker-server="$DOCKER_SERVER" \
        --docker-username="$DOCKER_USER" \
        --docker-password="$DOCKER_PASS"

    print_success "Docker registry secret created: $SECRET_NAME"
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    if [ -z "$SECRET_NAME" ]; then
        print_error "Secret name required"
        echo ""
        print_usage
        exit 1
    fi

    # Check prerequisites
    if ! require_kubectl; then
        return 1
    fi

    print_header "Create Kubernetes Secret: $SECRET_NAME"

    print_info "Namespace: $NAMESPACE"
    print_info "Type: $SECRET_TYPE"

    # Create namespace if needed
    k8s_create_namespace "$NAMESPACE"

    # Check if secret exists
    if k8s_secret_exists "$SECRET_NAME" "$NAMESPACE"; then
        print_warning "Secret '$SECRET_NAME' already exists"

        if ! confirm "Delete and recreate?"; then
            print_info "Cancelled"
            return 0
        fi

        k8s_secret_delete "$SECRET_NAME" "$NAMESPACE"
    fi

    # Create secret based on type
    case $SECRET_TYPE in
        generic)
            create_generic_secret
            ;;
        tls)
            create_tls_secret
            ;;
        docker)
            create_docker_secret
            ;;
    esac

    # Show secret info
    echo ""
    print_section "Secret Details"
    kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o yaml | grep -E "^  name:|^  namespace:|^  type:|^data:" | head -10

    echo ""
    print_info "View secret: make k8s-secret-show NAME=$SECRET_NAME NAMESPACE=$NAMESPACE"
}

main "$@"
exit $?
