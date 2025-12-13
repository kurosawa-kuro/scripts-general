#!/bin/bash
# =============================================================================
# Setup Cognito User Pool for PoC
# =============================================================================
#
# This script:
# 1. Creates a Cognito User Pool (if not exists)
# 2. Creates an App Client (if not exists)
# 3. Creates a test user with confirmed status
#
# Usage:
#   ./setup-cognito.sh [POOL_NAME] [ENVIRONMENT]
#
# Examples:
#   ./setup-cognito.sh my-app-users dev
#   ./setup-cognito.sh auth-pool stage
#
# Environment Variables:
#   AWS_REGION         - AWS region (default: ap-northeast-1)
#   TEST_USER_EMAIL    - Test user email (default: test@example.com)
#   TEST_USER_PASSWORD - Test user password (default: TempPass123!)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

# =============================================================================
# Configuration
# =============================================================================

POOL_NAME="${1}"
ENVIRONMENT="${2:-dev}"
REGION="$(aws_get_region)"

# Test user configuration
TEST_USER_EMAIL="${TEST_USER_EMAIL:-test@example.com}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-TempPass123!}"

# =============================================================================
# Cognito Functions (script-specific)
# =============================================================================

verify_setup() {
    local pool_id="$1"
    local client_id="$2"
    local region="$3"

    print_section "Verifying Setup"

    # Get User Pool details
    print_info "User Pool Details:"
    local pool_info=$(aws cognito-idp describe-user-pool \
        --user-pool-id "$pool_id" \
        --region "$region" \
        --output json 2>/dev/null)

    echo "  Name: $(json_get "$pool_info" '.UserPool.Name')"
    echo "  ID: $(json_get "$pool_info" '.UserPool.Id')"
    echo "  Status: $(json_get "$pool_info" '.UserPool.Status')"
    echo "  Created: $(json_get "$pool_info" '.UserPool.CreationDate')"

    # Get App Client details
    print_info "App Client ID: $client_id"

    # List users
    print_info "Users in pool:"
    aws cognito-idp list-users \
        --user-pool-id "$pool_id" \
        --region "$region" \
        --query "Users[].{Username: Username, Status: UserStatus, Email: Attributes[?Name=='email'].Value | [0]}" \
        --output table 2>/dev/null || echo "  (Unable to list users)"

    print_success "Setup verified"
    return 0
}

# =============================================================================
# Main
# =============================================================================

main() {
    local exit_code=0

    # Validate arguments
    if [ -z "$POOL_NAME" ]; then
        print_error "Pool name is required"
        echo ""
        echo "Usage: $0 [POOL_NAME] [ENVIRONMENT]"
        echo "Example: $0 my-app-users dev"
        exit 1
    fi

    local APP_CLIENT_NAME="${POOL_NAME}-client"

    print_header "Setting Up Cognito User Pool: $POOL_NAME"

    show_env_info "$ENVIRONMENT" "$REGION"
    print_info "Pool Name: $POOL_NAME"
    print_info "App Client Name: $APP_CLIENT_NAME"
    print_info "Test User Email: $TEST_USER_EMAIL"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        print_warning "Some features may be limited without jq"
    fi

    local POOL_ID=""
    local CLIENT_ID=""

    # Step 1: Create or get User Pool
    POOL_ID=$(cognito_get_pool_id "$POOL_NAME" "$REGION")
    if [ -n "$POOL_ID" ]; then
        print_success "User Pool '$POOL_NAME' already exists: $POOL_ID"
    else
        print_info "User Pool '$POOL_NAME' does not exist. Creating..."
        local result=$(cognito_create_user_pool "$POOL_NAME" "$REGION")
        POOL_ID=$(echo "$result" | jq -r '.UserPool.Id' 2>/dev/null)
        if [ -z "$POOL_ID" ] || [ "$POOL_ID" = "null" ]; then
            print_error "Failed to create User Pool"
            return 1
        fi
        print_success "User Pool created: $POOL_ID"
    fi

    # Step 2: Create or get App Client
    CLIENT_ID=$(cognito_get_client_id "$POOL_ID" "$APP_CLIENT_NAME" "$REGION")
    if [ -n "$CLIENT_ID" ]; then
        print_success "App Client '$APP_CLIENT_NAME' already exists: $CLIENT_ID"
    else
        print_info "App Client '$APP_CLIENT_NAME' does not exist. Creating..."
        local result=$(cognito_create_app_client "$POOL_ID" "$APP_CLIENT_NAME" "$REGION")
        CLIENT_ID=$(echo "$result" | jq -r '.UserPoolClient.ClientId' 2>/dev/null)
        if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "null" ]; then
            print_error "Failed to create App Client"
            return 1
        fi
        print_success "App Client created: $CLIENT_ID"
    fi

    # Step 3: Create test user
    if cognito_user_exists "$POOL_ID" "$TEST_USER_EMAIL" "$REGION"; then
        print_success "Test user '$TEST_USER_EMAIL' already exists"
    else
        print_info "Test user '$TEST_USER_EMAIL' does not exist. Creating..."
        if cognito_create_user "$POOL_ID" "$TEST_USER_EMAIL" "$TEST_USER_PASSWORD" "$REGION"; then
            print_success "Test user created"
        else
            print_warning "Failed to create test user"
            exit_code=1
        fi
    fi

    # Verify setup
    verify_setup "$POOL_ID" "$CLIENT_ID" "$REGION"

    # Summary
    echo ""
    if [ $exit_code -eq 0 ]; then
        print_success "Setup complete! All operations completed successfully."
    else
        print_warning "Setup completed with warnings. Some operations failed."
    fi

    echo ""
    print_section "Connection Information"
    echo ""
    echo "  User Pool ID:  $POOL_ID"
    echo "  Client ID:     $CLIENT_ID"
    echo "  Region:        $REGION"
    echo "  Test User:     $TEST_USER_EMAIL"
    echo "  Password:      $TEST_USER_PASSWORD"
    echo ""
    print_info "Useful commands:"
    print_info "  List users:  aws cognito-idp list-users --user-pool-id $POOL_ID --region $REGION"
    print_info "  Delete pool: aws cognito-idp delete-user-pool --user-pool-id $POOL_ID --region $REGION"

    return $exit_code
}

main "$@"
exit $?
