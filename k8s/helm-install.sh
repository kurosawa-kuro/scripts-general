#!/bin/bash
# =============================================================================
# Helm Chart Installation
# =============================================================================
# Purpose: Install or upgrade Helm charts
# Usage:
#   ./helm-install.sh RELEASE CHART [NAMESPACE]
#   ./helm-install.sh nginx ingress-nginx/ingress-nginx
#   ./helm-install.sh redis bitnami/redis -n redis -f values.yaml
#   ./helm-install.sh --help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/k8s.sh"

# =============================================================================
# Configuration
# =============================================================================

RELEASE_NAME="${1:-}"
CHART="${2:-}"
NAMESPACE="default"
VALUES_FILE=""
SET_VALUES=()
UPGRADE_MODE=false
DRY_RUN=false

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Helm Chart Installation"
    echo ""
    echo "Usage:"
    echo "  $0 RELEASE CHART [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NS    Install to namespace (default: default)"
    echo "  -f, --values FILE     Values file"
    echo "  --set KEY=VALUE       Set values"
    echo "  --upgrade             Upgrade if exists"
    echo "  --dry-run             Simulate installation"
    echo "  --help                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 nginx ingress-nginx/ingress-nginx"
    echo "  $0 redis bitnami/redis -n redis"
    echo "  $0 app ./my-chart -f values.yaml"
    echo "  $0 app ./my-chart --set image.tag=v1.0"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -f|--values)
                VALUES_FILE="$2"
                shift 2
                ;;
            --set)
                SET_VALUES+=("--set" "$2")
                shift 2
                ;;
            --upgrade)
                UPGRADE_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                if [ -z "$RELEASE_NAME" ]; then
                    RELEASE_NAME="$1"
                elif [ -z "$CHART" ]; then
                    CHART="$1"
                fi
                shift
                ;;
        esac
    done
}

install_chart() {
    print_header "Installing Helm Chart"

    print_info "Release:   $RELEASE_NAME"
    print_info "Chart:     $CHART"
    print_info "Namespace: $NAMESPACE"

    if [ -n "$VALUES_FILE" ]; then
        print_info "Values:    $VALUES_FILE"
    fi

    # Check if release exists
    local exists=false
    if helm_release_exists "$RELEASE_NAME" "$NAMESPACE"; then
        exists=true
        print_warning "Release '$RELEASE_NAME' already exists"

        if [ "$UPGRADE_MODE" = false ]; then
            if ! confirm "Upgrade existing release?"; then
                print_info "Cancelled"
                return 0
            fi
        fi
    fi

    # Build command
    local cmd
    if [ "$exists" = true ]; then
        cmd="helm upgrade $RELEASE_NAME $CHART"
    else
        cmd="helm install $RELEASE_NAME $CHART"
    fi

    cmd="$cmd -n $NAMESPACE --create-namespace"

    if [ -n "$VALUES_FILE" ]; then
        if [ ! -f "$VALUES_FILE" ]; then
            print_error "Values file not found: $VALUES_FILE"
            return 1
        fi
        cmd="$cmd -f $VALUES_FILE"
    fi

    if [ ${#SET_VALUES[@]} -gt 0 ]; then
        cmd="$cmd ${SET_VALUES[*]}"
    fi

    if [ "$DRY_RUN" = true ]; then
        cmd="$cmd --dry-run"
        print_info "Dry run mode"
    fi

    # Execute
    print_section "Installing"
    echo ""

    eval "$cmd"

    if [ "$DRY_RUN" = false ]; then
        echo ""
        if [ "$exists" = true ]; then
            print_success "Release upgraded successfully"
        else
            print_success "Release installed successfully"
        fi

        # Show status
        print_section "Release Status"
        helm status "$RELEASE_NAME" -n "$NAMESPACE" --show-resources 2>/dev/null | head -30
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    if [ -z "$RELEASE_NAME" ] || [ -z "$CHART" ]; then
        print_error "Release name and chart required"
        echo ""
        print_usage
        exit 1
    fi

    # Check prerequisites
    if ! require_helm; then
        return 1
    fi

    if ! require_kubectl; then
        return 1
    fi

    install_chart
}

main "$@"
exit $?
