#!/bin/bash
# =============================================================================
# ECR Image Cleanup
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

REPO_NAME="${1:-}"
REGION="$(aws_get_region)"
KEEP_COUNT=10
DRY_RUN=false

print_usage() {
    echo "ECR Image Cleanup"
    echo ""
    echo "Usage:"
    echo "  $0 REPO_NAME [OPTIONS]"
    echo "  $0 --all                    # Clean all repos"
    echo "  $0 --help"
    echo ""
    echo "Options:"
    echo "  --keep N        Keep last N images (default: 10)"
    echo "  --dry-run       Show what would be deleted"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep|-k) KEEP_COUNT="$2"; shift 2 ;;
            --dry-run|-n) DRY_RUN=true; shift ;;
            --all|-a) cleanup_all_repos; exit 0 ;;
            --help|-h) print_usage; exit 0 ;;
            *) [ -z "$REPO_NAME" ] && REPO_NAME="$1"; shift ;;
        esac
    done
}

cleanup_repo() {
    local repo="$1"

    print_section "Repository: $repo"

    # Get all images sorted by push date
    local images=$(aws ecr describe-images \
        --repository-name "$repo" \
        --region "$REGION" \
        --query 'imageDetails | sort_by(@, &imagePushedAt) | reverse(@)' \
        --output json 2>/dev/null)

    local total=$(echo "$images" | jq 'length')
    print_info "Total images: $total"
    print_info "Keeping: $KEEP_COUNT"

    if [ "$total" -le "$KEEP_COUNT" ]; then
        print_success "No cleanup needed"
        return 0
    fi

    # Get images to delete (all except last KEEP_COUNT)
    local to_delete=$(echo "$images" | jq --argjson keep "$KEEP_COUNT" '.[$keep:]')
    local delete_count=$(echo "$to_delete" | jq 'length')

    print_info "To delete: $delete_count"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would delete:"
        echo "$to_delete" | jq -r '.[] | "  \(.imageTags[0] // .imageDigest | .[0:12]) pushed \(.imagePushedAt)"'
        return 0
    fi

    # Build image IDs for deletion
    local image_ids=$(echo "$to_delete" | jq '[.[] | {imageDigest: .imageDigest}]')

    if [ "$delete_count" -gt 0 ]; then
        if confirm "Delete $delete_count images?"; then
            aws ecr batch-delete-image \
                --repository-name "$repo" \
                --region "$REGION" \
                --image-ids "$image_ids" \
                --output json > /dev/null

            print_success "Deleted $delete_count images"
        fi
    fi
}

cleanup_all_repos() {
    print_header "ECR Cleanup - All Repositories"

    local repos=$(aws ecr describe-repositories \
        --region "$REGION" \
        --query 'repositories[].repositoryName' \
        --output text 2>/dev/null)

    if [ -z "$repos" ]; then
        print_info "No repositories found"
        return 0
    fi

    for repo in $repos; do
        cleanup_repo "$repo"
        echo ""
    done

    print_success "Cleanup completed"
}

parse_args "$@"

if [ -z "$REPO_NAME" ]; then
    print_error "Repository name required"
    print_usage
    exit 1
fi

print_header "ECR Cleanup: $REPO_NAME"

if ! require_aws_cli; then exit 1; fi

cleanup_repo "$REPO_NAME"
