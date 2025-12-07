#!/bin/bash
# =============================================================================
# Helm Repository Management
# =============================================================================
# Purpose: Add, list, and update Helm repositories
# Usage:
#   ./helm-repo.sh                          # List repos
#   ./helm-repo.sh add NAME URL             # Add repo
#   ./helm-repo.sh update                   # Update all repos
#   ./helm-repo.sh remove NAME              # Remove repo
#   ./helm-repo.sh --help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/k8s.sh"

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Helm Repository Management"
    echo ""
    echo "Usage:"
    echo "  $0                          # List all repos"
    echo "  $0 add NAME URL             # Add repository"
    echo "  $0 update [NAME]            # Update repos"
    echo "  $0 remove NAME              # Remove repository"
    echo "  $0 search KEYWORD           # Search charts"
    echo "  $0 --common                 # Add common repos"
    echo "  $0 --help                   # Show this help"
    echo ""
    echo "Common Repositories:"
    echo "  bitnami   https://charts.bitnami.com/bitnami"
    echo "  ingress   https://kubernetes.github.io/ingress-nginx"
    echo "  jetstack  https://charts.jetstack.io"
    echo "  prometheus https://prometheus-community.github.io/helm-charts"
}

add_common_repos() {
    print_header "Adding Common Helm Repositories"

    local repos=(
        "bitnami https://charts.bitnami.com/bitnami"
        "ingress-nginx https://kubernetes.github.io/ingress-nginx"
        "jetstack https://charts.jetstack.io"
        "prometheus-community https://prometheus-community.github.io/helm-charts"
        "grafana https://grafana.github.io/helm-charts"
        "stable https://charts.helm.sh/stable"
    )

    for repo in "${repos[@]}"; do
        local name=$(echo "$repo" | cut -d' ' -f1)
        local url=$(echo "$repo" | cut -d' ' -f2)
        helm_repo_add "$name" "$url"
        print_success "Added: $name"
    done

    echo ""
    print_info "Updating all repositories..."
    helm repo update
    print_success "All repositories updated"
}

list_repos() {
    print_header "Helm Repositories"

    local repos=$(helm_repo_list)

    if [ -z "$repos" ]; then
        print_info "No Helm repositories configured"
        echo ""
        print_info "Add common repos: $0 --common"
        return 0
    fi

    echo "$repos"
}

add_repo() {
    local name="$1"
    local url="$2"

    if [ -z "$name" ] || [ -z "$url" ]; then
        print_error "Repository name and URL required"
        echo "Usage: $0 add NAME URL"
        return 1
    fi

    print_header "Adding Helm Repository: $name"

    helm_repo_add "$name" "$url"
    print_success "Repository added: $name"
}

remove_repo() {
    local name="$1"

    if [ -z "$name" ]; then
        print_error "Repository name required"
        return 1
    fi

    print_header "Removing Helm Repository: $name"

    if ! helm_repo_exists "$name"; then
        print_warning "Repository '$name' not found"
        return 0
    fi

    helm repo remove "$name"
    print_success "Repository removed: $name"
}

update_repos() {
    local name="$1"

    print_header "Updating Helm Repositories"

    if [ -n "$name" ]; then
        helm repo update "$name"
        print_success "Updated: $name"
    else
        helm repo update
        print_success "All repositories updated"
    fi
}

search_charts() {
    local keyword="$1"

    if [ -z "$keyword" ]; then
        print_error "Search keyword required"
        return 1
    fi

    print_header "Search Results: $keyword"

    helm search repo "$keyword" --max-col-width 60
}

# =============================================================================
# Main
# =============================================================================

main() {
    case "${1:-}" in
        --help|-h)
            print_usage
            exit 0
            ;;
        --common|-c)
            add_common_repos
            exit 0
            ;;
        add)
            shift
            add_repo "$@"
            exit $?
            ;;
        remove|rm)
            shift
            remove_repo "$@"
            exit $?
            ;;
        update)
            shift
            update_repos "$@"
            exit $?
            ;;
        search)
            shift
            search_charts "$@"
            exit $?
            ;;
    esac

    # Check prerequisites
    if ! require_helm; then
        return 1
    fi

    list_repos
}

main "$@"
exit $?
