#!/bin/bash
# =============================================================================
# Create Kubernetes Ingress
# =============================================================================
# Purpose: Create Ingress resources for routing external traffic
# Usage:
#   ./ingress-create.sh NAME --host HOST --service SVC --port PORT
#   ./ingress-create.sh NAME --from-file FILE
#   ./ingress-create.sh --help
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
NAMESPACE="default"
HOST=""
SERVICE=""
PORT=""
TLS_SECRET=""
INGRESS_CLASS="nginx"
FROM_FILE=""
PATH_PREFIX="/"

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Create Kubernetes Ingress"
    echo ""
    echo "Usage:"
    echo "  $0 NAME --host HOST --service SVC --port PORT"
    echo "  $0 NAME --from-file FILE"
    echo "  $0 --list [-n NAMESPACE]"
    echo "  $0 --help"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NS      Target namespace (default: default)"
    echo "  --host HOST             Hostname for the ingress"
    echo "  --service SVC           Backend service name"
    echo "  --port PORT             Backend service port"
    echo "  --path PATH             URL path prefix (default: /)"
    echo "  --tls SECRET            TLS secret name"
    echo "  --class CLASS           Ingress class (default: nginx)"
    echo "  --from-file FILE        Create from YAML file"
    echo ""
    echo "Examples:"
    echo "  $0 my-app --host app.example.com --service app-svc --port 80"
    echo "  $0 my-app --host app.example.com --service app-svc --port 80 --tls app-tls"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --host)
                HOST="$2"
                shift 2
                ;;
            --service)
                SERVICE="$2"
                shift 2
                ;;
            --port)
                PORT="$2"
                shift 2
                ;;
            --path)
                PATH_PREFIX="$2"
                shift 2
                ;;
            --tls)
                TLS_SECRET="$2"
                shift 2
                ;;
            --class)
                INGRESS_CLASS="$2"
                shift 2
                ;;
            --from-file)
                FROM_FILE="$2"
                shift 2
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

    if [ -n "$NAMESPACE" ] && [ "$NAMESPACE" != "default" ]; then
        print_info "Namespace: $NAMESPACE"
        echo ""
        k8s_ingress_list "$NAMESPACE"
    else
        print_info "All namespaces"
        echo ""
        k8s_ingress_list
    fi
}

create_ingress_from_file() {
    if [ ! -f "$FROM_FILE" ]; then
        print_error "File not found: $FROM_FILE"
        return 1
    fi

    print_section "Creating Ingress from file"
    kubectl apply -f "$FROM_FILE" -n "$NAMESPACE"
    print_success "Ingress created from $FROM_FILE"
}

create_ingress() {
    print_section "Creating Ingress"

    # Build ingress YAML
    local tls_section=""
    if [ -n "$TLS_SECRET" ]; then
        tls_section="
  tls:
  - hosts:
    - $HOST
    secretName: $TLS_SECRET"
    fi

    local ingress_yaml=$(cat <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $INGRESS_NAME
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/ingress.class: $INGRESS_CLASS
spec:${tls_section}
  rules:
  - host: $HOST
    http:
      paths:
      - path: $PATH_PREFIX
        pathType: Prefix
        backend:
          service:
            name: $SERVICE
            port:
              number: $PORT
EOF
)

    echo "$ingress_yaml" | kubectl apply -f -
    print_success "Ingress created: $INGRESS_NAME"
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

    # Create from file
    if [ -n "$FROM_FILE" ]; then
        create_ingress_from_file
        exit $?
    fi

    # Validate required arguments
    if [ -z "$INGRESS_NAME" ]; then
        print_error "Ingress name required"
        echo ""
        print_usage
        exit 1
    fi

    if [ -z "$HOST" ] || [ -z "$SERVICE" ] || [ -z "$PORT" ]; then
        print_error "--host, --service, and --port are required"
        echo ""
        print_usage
        exit 1
    fi

    print_header "Create Kubernetes Ingress: $INGRESS_NAME"

    print_info "Namespace: $NAMESPACE"
    print_info "Host: $HOST"
    print_info "Service: $SERVICE:$PORT"
    print_info "Path: $PATH_PREFIX"
    print_info "Class: $INGRESS_CLASS"
    if [ -n "$TLS_SECRET" ]; then
        print_info "TLS: $TLS_SECRET"
    fi

    # Create namespace if needed
    k8s_create_namespace "$NAMESPACE"

    # Check if ingress exists
    if k8s_ingress_exists "$INGRESS_NAME" "$NAMESPACE"; then
        print_warning "Ingress '$INGRESS_NAME' already exists"

        if ! confirm "Update existing ingress?"; then
            print_info "Cancelled"
            return 0
        fi
    fi

    create_ingress

    # Show ingress details
    echo ""
    print_section "Ingress Details"
    kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o wide

    echo ""
    print_info "Note: Ensure ingress controller is installed"
    print_info "Install nginx-ingress: make helm-install RELEASE=nginx CHART=ingress-nginx/ingress-nginx"
}

main "$@"
exit $?
