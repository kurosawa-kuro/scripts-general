#!/bin/bash
# =============================================================================
# Docker Login to ECR
# =============================================================================
#
# This script:
# 1. Gets ECR login credentials
# 2. Performs docker login to ECR registry
#
# Usage:
#   ./docker-login-ecr.sh
#
# Examples:
#   ./docker-login-ecr.sh
#   AWS_REGION=us-east-1 ./docker-login-ecr.sh
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

# =============================================================================
# Configuration
# =============================================================================

REGION="$(aws_get_region)"

# =============================================================================
# Main
# =============================================================================

main() {
    print_header "Docker Login to ECR"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! command -v docker &> /dev/null; then
        print_error "docker is not installed"
        print_info "Install: https://docs.docker.com/get-docker/"
        return 1
    fi

    # Get account info
    local account_id=$(aws_get_account_id)
    if [ -z "$account_id" ]; then
        print_error "Failed to get AWS account ID"
        return 1
    fi

    local registry_url=$(ecr_get_registry_url "$account_id" "$REGION")

    print_info "Account ID: $account_id"
    print_info "Region: $REGION"
    print_info "Registry: $registry_url"
    echo ""

    # Perform login
    print_info "Logging in to ECR..."

    if ecr_docker_login "$REGION" "$account_id"; then
        print_success "Login successful!"
        echo ""
        print_info "Token is valid for 12 hours"
        print_info "Registry: $registry_url"
        echo ""
        print_info "Example push:"
        print_info "  docker tag my-image:latest $registry_url/my-repo:latest"
        print_info "  docker push $registry_url/my-repo:latest"
    else
        print_error "Login failed!"
        echo ""
        print_info "Troubleshooting:"
        echo "  1. Verify AWS credentials are configured"
        echo "  2. Check IAM permissions for ecr:GetAuthorizationToken"
        echo "  3. Ensure Docker daemon is running"
        return 1
    fi

    return 0
}

main "$@"
exit $?
