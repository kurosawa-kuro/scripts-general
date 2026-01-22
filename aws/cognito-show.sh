#!/bin/bash
# =============================================================================
# Check Cognito Login Script
# =============================================================================
#
# This script:
# 1. Tests user authentication with Cognito User Pool
# 2. Verifies credentials work correctly
# 3. Returns authentication tokens on success
#
# Usage:
#   ./check-cognito.sh [POOL_NAME] [EMAIL] [PASSWORD]
#   ./check-cognito.sh --pool-id [POOL_ID] --client-id [CLIENT_ID] [EMAIL] [PASSWORD]
#
# Examples:
#   ./check-cognito.sh my-app-users test@example.com TempPass123!
#   ./check-cognito.sh --pool-id ap-northeast-1_XXXXX --client-id XXXXX test@example.com Pass123!
#
# Environment Variables:
#   AWS_REGION         - AWS region (default: ap-northeast-1)
#   COGNITO_POOL_ID    - User Pool ID (alternative to --pool-id)
#   COGNITO_CLIENT_ID  - App Client ID (alternative to --client-id)
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
POOL_ID="${COGNITO_POOL_ID:-}"
CLIENT_ID="${COGNITO_CLIENT_ID:-}"
POOL_NAME=""
EMAIL=""
PASSWORD=""

# =============================================================================
# Utility Functions
# =============================================================================

print_usage() {
    echo "Check Cognito Login Script"
    echo ""
    echo "Usage:"
    echo "  $0 [POOL_NAME] [EMAIL] [PASSWORD]"
    echo "  $0 --pool-id [POOL_ID] --client-id [CLIENT_ID] [EMAIL] [PASSWORD]"
    echo ""
    echo "Arguments:"
    echo "  POOL_NAME    User Pool name (will lookup Pool ID and Client ID)"
    echo "  EMAIL        User email address"
    echo "  PASSWORD     User password"
    echo ""
    echo "Options:"
    echo "  --pool-id    Specify User Pool ID directly"
    echo "  --client-id  Specify App Client ID directly"
    echo "  --help       Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION         AWS region (default: ap-northeast-1)"
    echo "  COGNITO_POOL_ID    User Pool ID"
    echo "  COGNITO_CLIENT_ID  App Client ID"
    echo ""
    echo "Examples:"
    echo "  $0 my-app-users test@example.com TempPass123!"
    echo "  $0 --pool-id ap-northeast-1_XXXXX --client-id XXXXX user@example.com Pass123!"
}

# =============================================================================
# Cognito Functions (script-specific)
# =============================================================================

get_first_app_client_id() {
    local pool_id="$1"
    local region="$2"

    # Get the first client for this pool
    aws cognito-idp list-user-pool-clients \
        --user-pool-id "$pool_id" \
        --region "$region" \
        --query "UserPoolClients[0].ClientId" \
        --output text 2>/dev/null | grep -v "^None$"
}

test_login() {
    local pool_id="$1"
    local client_id="$2"
    local email="$3"
    local password="$4"
    local region="$5"

    print_section "Testing Authentication"
    print_info "User Pool ID: $pool_id"
    print_info "Client ID: $client_id"
    print_info "Email: $email"
    print_info "Region: $region"
    echo ""

    # Attempt authentication using USER_PASSWORD_AUTH flow
    print_info "Attempting login..."

    local result=$(cognito_auth "$client_id" "$email" "$password" "$region")
    local exit_code=$?

    if [ $exit_code -eq 0 ] && ! echo "$result" | grep -q "error"; then
        # Check if we got tokens or a challenge
        local challenge=$(json_get "$result" '.ChallengeName')
        local access_token=$(json_get "$result" '.AuthenticationResult.AccessToken')
        local id_token=$(json_get "$result" '.AuthenticationResult.IdToken')
        local refresh_token=$(json_get "$result" '.AuthenticationResult.RefreshToken')
        local expires_in=$(json_get "$result" '.AuthenticationResult.ExpiresIn')

        if [ -n "$challenge" ]; then
            print_warning "Authentication requires challenge: $challenge"

            if [ "$challenge" = "NEW_PASSWORD_REQUIRED" ]; then
                print_info "User needs to set a new password"
                print_info "Use admin-set-user-password to set permanent password"
            fi
            return 2
        fi

        if [ -n "$access_token" ]; then
            print_success "Authentication successful!"
            echo ""
            print_section "Token Information"
            echo -e "  Access Token:  ${CYAN}${access_token:0:50}...${NC}"
            echo -e "  ID Token:      ${CYAN}${id_token:0:50}...${NC}"
            echo -e "  Refresh Token: ${CYAN}${refresh_token:0:50}...${NC}"
            echo -e "  Expires In:    ${CYAN}${expires_in} seconds${NC}"

            # Decode ID token to show user info
            if [ -n "$id_token" ]; then
                print_section "User Information (from ID Token)"
                # Extract payload from JWT (second part)
                local payload=$(echo "$id_token" | cut -d'.' -f2)
                # Add padding if needed and decode
                local padded_payload="${payload}$(printf '%*s' $((4 - ${#payload} % 4)) '' | tr ' ' '=')"
                local decoded=$(echo "$padded_payload" | base64 -d 2>/dev/null || echo "{}")

                if [ -n "$decoded" ]; then
                    local user_email=$(json_get "$decoded" '.email' 'N/A')
                    local user_sub=$(json_get "$decoded" '.sub' 'N/A')
                    local email_verified=$(json_get "$decoded" '.email_verified' 'N/A')
                    echo -e "  Email:          ${CYAN}$user_email${NC}"
                    echo -e "  User Sub:       ${CYAN}$user_sub${NC}"
                    echo -e "  Email Verified: ${CYAN}$email_verified${NC}"
                fi
            fi

            return 0
        fi
    else
        # Authentication failed
        print_error "Authentication failed!"
        echo ""

        # Parse error message
        if echo "$result" | grep -q "NotAuthorizedException"; then
            print_error "Incorrect username or password"
        elif echo "$result" | grep -q "UserNotFoundException"; then
            print_error "User does not exist"
        elif echo "$result" | grep -q "UserNotConfirmedException"; then
            print_error "User is not confirmed"
        elif echo "$result" | grep -q "PasswordResetRequiredException"; then
            print_error "Password reset is required"
        else
            print_error "Error details:"
            echo "$result" | head -5
        fi

        return 1
    fi
}

# =============================================================================
# Parse Arguments
# =============================================================================

parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --pool-id)
                POOL_ID="$2"
                shift 2
                ;;
            --client-id)
                CLIENT_ID="$2"
                shift 2
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                # Positional arguments
                if [ -z "$POOL_NAME" ] && [ -z "$POOL_ID" ]; then
                    POOL_NAME="$1"
                elif [ -z "$EMAIL" ]; then
                    EMAIL="$1"
                elif [ -z "$PASSWORD" ]; then
                    PASSWORD="$1"
                fi
                shift
                ;;
        esac
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    print_header "Cognito Login Check"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        print_warning "Some features may be limited without jq"
    fi

    # Validate required arguments
    if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
        print_error "Email and password are required"
        echo ""
        print_usage
        exit 1
    fi

    # If Pool ID not provided, look it up by name
    if [ -z "$POOL_ID" ]; then
        if [ -z "$POOL_NAME" ]; then
            print_error "Either POOL_NAME or --pool-id is required"
            echo ""
            print_usage
            exit 1
        fi

        print_info "Looking up User Pool ID for '$POOL_NAME'..."
        POOL_ID=$(cognito_get_pool_id "$POOL_NAME" "$REGION")

        if [ -z "$POOL_ID" ]; then
            print_error "User Pool '$POOL_NAME' not found"
            exit 1
        fi
        print_success "Found Pool ID: $POOL_ID"
    fi

    # If Client ID not provided, look it up
    if [ -z "$CLIENT_ID" ]; then
        print_info "Looking up App Client ID..."
        CLIENT_ID=$(get_first_app_client_id "$POOL_ID" "$REGION")

        if [ -z "$CLIENT_ID" ]; then
            print_error "No App Client found for User Pool"
            exit 1
        fi
        print_success "Found Client ID: $CLIENT_ID"
    fi

    # Test login
    test_login "$POOL_ID" "$CLIENT_ID" "$EMAIL" "$PASSWORD" "$REGION"
    local result=$?

    # Summary
    echo ""
    print_section "Summary"
    if [ $result -eq 0 ]; then
        print_success "Login test passed! User can authenticate successfully."
    elif [ $result -eq 2 ]; then
        print_warning "Login requires additional action (challenge)."
    else
        print_error "Login test failed! Check credentials and try again."
    fi

    return $result
}

main "$@"
exit $?
