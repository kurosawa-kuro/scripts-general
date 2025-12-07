#!/bin/bash
# =============================================================================
# Check ECR Repository
# =============================================================================
#
# This script:
# 1. Shows repository information
# 2. Lists images with tags, size, and push date
# 3. Shows scan results (if available)
#
# Usage:
#   ./check-ecr.sh [REPO_NAME]
#   ./check-ecr.sh --list
#
# Examples:
#   ./check-ecr.sh my-app
#   ./check-ecr.sh --list
#
# Environment Variables:
#   AWS_REGION - AWS region (default: ap-northeast-1)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

# =============================================================================
# Configuration
# =============================================================================

REPO_NAME="${1}"
REGION="$(aws_get_region)"

# =============================================================================
# Functions
# =============================================================================

list_repositories() {
    print_section "ECR Repositories"

    local repos=$(aws ecr describe-repositories --region "$REGION" --output json 2>/dev/null)

    if [ -z "$repos" ]; then
        print_info "No repositories found"
        return 0
    fi

    local count=$(echo "$repos" | jq -r '.repositories | length')

    if [ "$count" -eq 0 ]; then
        print_info "No repositories found"
        return 0
    fi

    print_success "Found $count repository(s)"
    echo ""

    echo "$repos" | jq -r '.repositories[] | "  \(.repositoryName) - \(.repositoryUri)"'
}

show_repo_info() {
    local repo_name="$1"

    print_section "Repository Information"

    local repo_info=$(ecr_get_repo_info "$repo_name" "$REGION")

    if [ -z "$repo_info" ] || echo "$repo_info" | grep -q "RepositoryNotFoundException"; then
        print_error "Repository '$repo_name' not found"
        return 1
    fi

    local repo_uri=$(json_get "$repo_info" '.repositories[0].repositoryUri')
    local repo_arn=$(json_get "$repo_info" '.repositories[0].repositoryArn')
    local created_at=$(json_get "$repo_info" '.repositories[0].createdAt')
    local scan_config=$(json_get "$repo_info" '.repositories[0].imageScanningConfiguration.scanOnPush')
    local tag_mutability=$(json_get "$repo_info" '.repositories[0].imageTagMutability')

    echo "  Name:           $repo_name"
    echo "  URI:            $repo_uri"
    echo "  ARN:            $repo_arn"
    echo "  Created:        $created_at"
    echo "  Scan on Push:   $scan_config"
    echo "  Tag Mutability: $tag_mutability"
}

show_images() {
    local repo_name="$1"

    print_section "Images"

    local images=$(ecr_list_images "$repo_name" "$REGION")

    if [ -z "$images" ] || [ "$images" = "null" ] || [ "$images" = "[]" ]; then
        print_info "No images found"
        return 0
    fi

    local count=$(echo "$images" | jq -r 'length')
    print_success "Found $count image(s)"
    echo ""

    # Display as table
    printf "  %-20s %-15s %-25s %s\n" "TAG" "SIZE" "PUSHED" "DIGEST"
    printf "  %-20s %-15s %-25s %s\n" "---" "----" "------" "------"

    echo "$images" | jq -r 'sort_by(.Pushed) | reverse | .[] | [
        (.Tags // "untagged"),
        ((.Size / 1024 / 1024 | floor | tostring) + " MB"),
        (.Pushed | split("T")[0]),
        (.Digest | split(":")[1][:12])
    ] | @tsv' | while IFS=$'\t' read -r tag size pushed digest; do
        printf "  %-20s %-15s %-25s %s\n" "$tag" "$size" "$pushed" "$digest"
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Handle --list flag
    if [ "$REPO_NAME" = "--list" ] || [ "$REPO_NAME" = "-l" ]; then
        print_header "ECR Repositories"

        if ! require_aws_cli; then
            return 1
        fi

        list_repositories
        return 0
    fi

    # Validate arguments
    if [ -z "$REPO_NAME" ]; then
        print_error "Repository name is required"
        echo ""
        echo "Usage: $0 [REPO_NAME]"
        echo "       $0 --list"
        echo ""
        echo "Example: $0 my-app"
        exit 1
    fi

    print_header "ECR Repository: $REPO_NAME"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        print_error "jq is required for this script"
        return 1
    fi

    # Show repository info
    if ! show_repo_info "$REPO_NAME"; then
        return 1
    fi

    # Show images
    show_images "$REPO_NAME"

    # Summary
    echo ""
    print_info "Useful commands:"
    print_info "  Login:  ./docker-login-ecr.sh"
    print_info "  Pull:   docker pull $(ecr_get_registry_url)/$REPO_NAME:latest"
    print_info "  Delete: aws ecr batch-delete-image --repository-name $REPO_NAME --image-ids imageTag=TAG"

    return 0
}

main "$@"
exit $?
