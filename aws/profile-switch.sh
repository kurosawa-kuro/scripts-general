#!/bin/bash
# =============================================================================
# AWS Profile Switcher
# =============================================================================
#
# This script:
# 1. Lists available AWS profiles
# 2. Shows current profile and account info
# 3. Helps switch profiles (outputs export command)
#
# Usage:
#   ./setup-aws-profile.sh [PROFILE_NAME]
#   ./setup-aws-profile.sh --list
#   ./setup-aws-profile.sh --current
#
# Examples:
#   ./setup-aws-profile.sh --list
#   ./setup-aws-profile.sh --current
#   ./setup-aws-profile.sh work
#   source <(./setup-aws-profile.sh work --export)
#
# Flags:
#   --list, -l     List all available profiles
#   --current, -c  Show current profile info
#   --export, -e   Output export command (for sourcing)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

# =============================================================================
# Configuration
# =============================================================================

PROFILE_NAME=""
SHOW_LIST=false
SHOW_CURRENT=false
EXPORT_MODE=false

# =============================================================================
# Parse Arguments
# =============================================================================

parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --list|-l)
                SHOW_LIST=true
                shift
                ;;
            --current|-c)
                SHOW_CURRENT=true
                shift
                ;;
            --export|-e)
                EXPORT_MODE=true
                shift
                ;;
            --help|-h)
                echo "AWS Profile Switcher"
                echo ""
                echo "Usage: $0 [PROFILE_NAME] [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --list, -l     List all available profiles"
                echo "  --current, -c  Show current profile info"
                echo "  --export, -e   Output export command (for sourcing)"
                echo "  --help, -h     Show this help"
                echo ""
                echo "Examples:"
                echo "  $0 --list"
                echo "  $0 --current"
                echo "  $0 work"
                echo "  source <($0 work --export)"
                exit 0
                ;;
            *)
                PROFILE_NAME="$1"
                shift
                ;;
        esac
    done
}

# =============================================================================
# Functions
# =============================================================================

get_aws_config_file() {
    echo "${AWS_CONFIG_FILE:-$HOME/.aws/config}"
}

get_aws_credentials_file() {
    echo "${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
}

list_profiles() {
    local config_file=$(get_aws_config_file)
    local creds_file=$(get_aws_credentials_file)

    local profiles=""

    # Get profiles from config file
    if [ -f "$config_file" ]; then
        local config_profiles=$(grep '^\[' "$config_file" | sed 's/\[profile \(.*\)\]/\1/' | sed 's/\[\(.*\)\]/\1/' | grep -v '^default$')
        profiles="$config_profiles"
    fi

    # Get profiles from credentials file
    if [ -f "$creds_file" ]; then
        local cred_profiles=$(grep '^\[' "$creds_file" | sed 's/\[\(.*\)\]/\1/')
        if [ -n "$profiles" ]; then
            profiles="$profiles"$'\n'"$cred_profiles"
        else
            profiles="$cred_profiles"
        fi
    fi

    # Sort and unique
    echo "$profiles" | sort -u
}

show_profiles() {
    print_section "Available AWS Profiles"

    local profiles=$(list_profiles)

    if [ -z "$profiles" ]; then
        print_warning "No AWS profiles found"
        print_info "Config file: $(get_aws_config_file)"
        print_info "Credentials file: $(get_aws_credentials_file)"
        return 1
    fi

    local current="${AWS_PROFILE:-default}"

    echo "$profiles" | while read -r profile; do
        if [ "$profile" = "$current" ]; then
            echo -e "  ${GREEN}* $profile${NC} (current)"
        else
            echo "    $profile"
        fi
    done
}

show_current() {
    print_section "Current AWS Profile"

    local current="${AWS_PROFILE:-default}"
    print_info "Profile: $current"

    # Try to get account info
    if command -v aws &> /dev/null; then
        local identity=$(aws sts get-caller-identity --output json 2>/dev/null)
        if [ -n "$identity" ]; then
            local account=$(json_get "$identity" '.Account')
            local arn=$(json_get "$identity" '.Arn')
            local user_id=$(json_get "$identity" '.UserId')

            print_info "Account: $account"
            print_info "ARN: $arn"
            print_info "User ID: $user_id"

            # Get region
            local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null)}}"
            print_info "Region: ${region:-not set}"
        else
            print_warning "Could not get identity (check credentials)"
        fi
    else
        print_warning "AWS CLI not installed"
    fi
}

switch_profile() {
    local profile="$1"

    # Validate profile exists
    local profiles=$(list_profiles)
    if ! echo "$profiles" | grep -q "^${profile}$"; then
        print_error "Profile '$profile' not found"
        echo ""
        show_profiles
        return 1
    fi

    if [ "$EXPORT_MODE" = true ]; then
        # Output export command for sourcing
        echo "export AWS_PROFILE=$profile"
    else
        # Show instructions
        print_section "Switch to Profile: $profile"

        echo ""
        echo "Run one of these commands:"
        echo ""
        echo -e "  ${CYAN}# For current session:${NC}"
        echo -e "  export AWS_PROFILE=$profile"
        echo ""
        echo -e "  ${CYAN}# Or source this script:${NC}"
        echo -e "  source <($0 $profile --export)"
        echo ""
        echo -e "  ${CYAN}# Or add to ~/.bashrc or ~/.zshrc:${NC}"
        echo -e "  echo 'export AWS_PROFILE=$profile' >> ~/.bashrc"
        echo ""

        # Verify profile works
        print_info "Testing profile '$profile'..."
        local identity=$(AWS_PROFILE="$profile" aws sts get-caller-identity --output json 2>/dev/null)
        if [ -n "$identity" ]; then
            local account=$(json_get "$identity" '.Account')
            print_success "Profile valid - Account: $account"
        else
            print_warning "Could not verify profile (check credentials)"
        fi
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    # Don't print header in export mode
    if [ "$EXPORT_MODE" = false ]; then
        print_header "AWS Profile Manager"
    fi

    # Check for jq
    if ! command -v jq &> /dev/null && [ "$EXPORT_MODE" = false ]; then
        print_warning "jq not installed - some features limited"
    fi

    # Handle modes
    if [ "$SHOW_LIST" = true ]; then
        show_profiles
        return 0
    fi

    if [ "$SHOW_CURRENT" = true ]; then
        show_current
        return 0
    fi

    if [ -n "$PROFILE_NAME" ]; then
        switch_profile "$PROFILE_NAME"
        return $?
    fi

    # Default: show current and list
    show_current
    echo ""
    show_profiles
}

main "$@"
exit $?
