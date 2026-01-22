#!/bin/bash
# =============================================================================
# Setup ECR Repository for PoC
# =============================================================================
#
# This script:
# 1. Creates an ECR repository (if not exists)
# 2. Configures image scanning
# 3. Sets lifecycle policy (optional)
#
# Usage:
#   ./setup-ecr.sh [REPO_NAME]
#
# Examples:
#   ./setup-ecr.sh my-app
#   ./setup-ecr.sh my-service
#
# Environment Variables:
#   AWS_REGION              - AWS region (default: ap-northeast-1)
#   ECR_SCAN_ON_PUSH        - Enable scan on push (default: true)
#   ECR_TAG_MUTABILITY      - MUTABLE or IMMUTABLE (default: MUTABLE)
#   ECR_LIFECYCLE_MAX_IMAGES - Max images to keep (default: 30, 0 to disable)
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

# ECR configuration
ECR_SCAN_ON_PUSH="${ECR_SCAN_ON_PUSH:-true}"
ECR_TAG_MUTABILITY="${ECR_TAG_MUTABILITY:-MUTABLE}"
ECR_LIFECYCLE_MAX_IMAGES="${ECR_LIFECYCLE_MAX_IMAGES:-30}"

# =============================================================================
# Main
# =============================================================================

main() {
    local exit_code=0

    # Validate arguments
    if [ -z "$REPO_NAME" ]; then
        print_error "Repository name is required"
        echo ""
        echo "Usage: $0 [REPO_NAME]"
        echo "Example: $0 my-app"
        exit 1
    fi

    print_header "Setting Up ECR Repository: $REPO_NAME"

    show_env_info "ecr" "$REGION"
    print_info "Repository: $REPO_NAME"
    print_info "Scan on Push: $ECR_SCAN_ON_PUSH"
    print_info "Tag Mutability: $ECR_TAG_MUTABILITY"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        print_warning "Some features may be limited without jq"
    fi

    # Step 1: Check if repository exists
    if ecr_repo_exists "$REPO_NAME" "$REGION"; then
        print_success "Repository '$REPO_NAME' already exists"

        # Show existing repo info
        print_section "Repository Information"
        local repo_info=$(ecr_get_repo_info "$REPO_NAME" "$REGION")
        local repo_uri=$(json_get "$repo_info" '.repositories[0].repositoryUri')
        local created_at=$(json_get "$repo_info" '.repositories[0].createdAt')

        echo "  URI: $repo_uri"
        echo "  Created: $created_at"
    else
        print_info "Repository '$REPO_NAME' does not exist. Creating..."

        # Step 2: Create repository
        if ecr_create_repo "$REPO_NAME" "$REGION" "$ECR_SCAN_ON_PUSH" "$ECR_TAG_MUTABILITY" > /dev/null; then
            print_success "Repository created successfully"
        else
            print_error "Failed to create repository"
            return 1
        fi

        # Step 3: Set lifecycle policy if enabled
        if [ "$ECR_LIFECYCLE_MAX_IMAGES" -gt 0 ]; then
            print_info "Setting lifecycle policy (keep last $ECR_LIFECYCLE_MAX_IMAGES images)..."
            if ecr_set_lifecycle_policy "$REPO_NAME" "$REGION" "$ECR_LIFECYCLE_MAX_IMAGES" > /dev/null; then
                print_success "Lifecycle policy set"
            else
                print_warning "Failed to set lifecycle policy (non-critical)"
            fi
        fi
    fi

    # Get repository info
    local account_id=$(aws_get_account_id)
    local registry_url=$(ecr_get_registry_url "$account_id" "$REGION")
    local repo_uri="${registry_url}/${REPO_NAME}"

    # Summary
    echo ""
    print_success "Setup complete!"

    echo ""
    print_section "Connection Information"
    echo ""
    echo "  Repository:    $REPO_NAME"
    echo "  Registry URL:  $registry_url"
    echo "  Repository URI: $repo_uri"
    echo "  Region:        $REGION"
    echo ""
    print_info "Useful commands:"
    print_info "  Login:  ./docker-login-ecr.sh"
    print_info "  Push:   docker tag my-image:latest $repo_uri:latest"
    print_info "          docker push $repo_uri:latest"
    print_info "  List:   ./check-ecr.sh $REPO_NAME"
    print_info "  Delete: aws ecr delete-repository --repository-name $REPO_NAME --region $REGION --force"

    return $exit_code
}

main "$@"
exit $?
