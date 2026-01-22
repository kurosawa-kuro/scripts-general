#!/bin/bash
# =============================================================================
# Setup AWS Parameter Store
# =============================================================================
#
# This script:
# 1. Creates or updates a parameter in AWS Systems Manager Parameter Store
# 2. Supports String, StringList, and SecureString types
# 3. Can read value from stdin for secure input
#
# Usage:
#   ./setup-param-store.sh PARAM_NAME PARAM_VALUE [OPTIONS]
#   echo "secret" | ./setup-param-store.sh PARAM_NAME --stdin
#
# Examples:
#   ./setup-param-store.sh /myapp/config/db_host localhost
#   ./setup-param-store.sh /myapp/secrets/api_key "abc123" --secure
#   ./setup-param-store.sh /myapp/config/hosts "host1,host2" --type StringList
#   echo "secret" | ./setup-param-store.sh /myapp/secrets/password --stdin --secure
#
# Flags:
#   --type, -t      Parameter type: String, StringList, SecureString (default: String)
#   --secure, -s    Shortcut for --type SecureString
#   --desc, -d      Parameter description
#   --stdin         Read value from stdin
#   --no-overwrite  Don't overwrite if exists
#   --delete        Delete the parameter
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

PARAM_NAME=""
PARAM_VALUE=""
PARAM_TYPE="String"
PARAM_DESC=""
OVERWRITE=true
DELETE_MODE=false
READ_STDIN=false
REGION="$(aws_get_region)"

# =============================================================================
# Parse Arguments
# =============================================================================

parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --type|-t)
                PARAM_TYPE="$2"
                shift 2
                ;;
            --secure|-s)
                PARAM_TYPE="SecureString"
                shift
                ;;
            --desc|-d)
                PARAM_DESC="$2"
                shift 2
                ;;
            --stdin)
                READ_STDIN=true
                shift
                ;;
            --no-overwrite)
                OVERWRITE=false
                shift
                ;;
            --delete)
                DELETE_MODE=true
                shift
                ;;
            --help|-h)
                echo "Setup AWS Parameter Store"
                echo ""
                echo "Usage: $0 PARAM_NAME [PARAM_VALUE] [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --type, -t TYPE    Parameter type: String, StringList, SecureString"
                echo "  --secure, -s       Shortcut for --type SecureString"
                echo "  --desc, -d DESC    Parameter description"
                echo "  --stdin            Read value from stdin"
                echo "  --no-overwrite     Don't overwrite if exists"
                echo "  --delete           Delete the parameter"
                echo "  --help, -h         Show this help"
                echo ""
                echo "Examples:"
                echo "  $0 /myapp/config/db_host localhost"
                echo "  $0 /myapp/secrets/api_key \"abc123\" --secure"
                echo "  echo \"secret\" | $0 /myapp/secrets/password --stdin --secure"
                echo "  $0 /myapp/config/old_param --delete"
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                exit 1
                ;;
            *)
                if [ -z "$PARAM_NAME" ]; then
                    PARAM_NAME="$1"
                elif [ -z "$PARAM_VALUE" ]; then
                    PARAM_VALUE="$1"
                fi
                shift
                ;;
        esac
    done

    # Read from stdin if requested
    if [ "$READ_STDIN" = true ]; then
        PARAM_VALUE=$(cat)
    fi
}

# =============================================================================
# Functions
# =============================================================================

validate_param_name() {
    local name="$1"

    # Must start with /
    if [[ ! "$name" =~ ^/ ]]; then
        print_error "Parameter name must start with '/'"
        print_info "Example: /myapp/config/db_host"
        return 1
    fi

    # Valid characters check
    if [[ ! "$name" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        print_error "Parameter name contains invalid characters"
        print_info "Allowed: letters, numbers, /, _, ., -"
        return 1
    fi

    return 0
}

delete_parameter() {
    local name="$1"

    if ! ssm_param_exists "$name" "$REGION"; then
        print_warning "Parameter '$name' does not exist"
        return 0
    fi

    print_info "Deleting parameter: $name"

    if ssm_delete_param "$name" "$REGION"; then
        print_success "Parameter deleted"
    else
        print_error "Failed to delete parameter"
        return 1
    fi
}

create_parameter() {
    local name="$1"
    local value="$2"
    local type="$3"
    local desc="$4"

    local exists=false
    if ssm_param_exists "$name" "$REGION"; then
        exists=true
        if [ "$OVERWRITE" = false ]; then
            print_warning "Parameter '$name' already exists (--no-overwrite specified)"
            return 0
        fi
    fi

    if [ "$exists" = true ]; then
        print_info "Updating parameter: $name"
    else
        print_info "Creating parameter: $name"
    fi

    # Build and execute command
    local result
    if [ -n "$desc" ]; then
        result=$(aws ssm put-parameter \
            --name "$name" \
            --value "$value" \
            --type "$type" \
            --description "$desc" \
            --region "$REGION" \
            $( [ "$OVERWRITE" = true ] && echo "--overwrite" ) \
            --output json 2>&1)
    else
        result=$(aws ssm put-parameter \
            --name "$name" \
            --value "$value" \
            --type "$type" \
            --region "$REGION" \
            $( [ "$OVERWRITE" = true ] && echo "--overwrite" ) \
            --output json 2>&1)
    fi

    if [ $? -eq 0 ]; then
        local version=$(echo "$result" | jq -r '.Version' 2>/dev/null)
        if [ "$exists" = true ]; then
            print_success "Parameter updated (version: $version)"
        else
            print_success "Parameter created (version: $version)"
        fi
    else
        print_error "Failed to create/update parameter"
        echo "$result" | head -3
        return 1
    fi
}

show_parameter_info() {
    local name="$1"

    print_section "Parameter Info"

    local info=$(ssm_get_param "$name" "$REGION" true 2>/dev/null)

    if [ -z "$info" ]; then
        print_warning "Could not retrieve parameter info"
        return
    fi

    local type=$(json_get "$info" '.Parameter.Type')
    local version=$(json_get "$info" '.Parameter.Version')
    local last_modified=$(json_get "$info" '.Parameter.LastModifiedDate')
    local arn=$(json_get "$info" '.Parameter.ARN')

    print_info "Name: $name"
    print_info "Type: $type"
    print_info "Version: $version"
    print_info "Last Modified: $last_modified"
    print_info "ARN: $arn"

    if [ "$type" != "SecureString" ]; then
        local value=$(json_get "$info" '.Parameter.Value')
        print_info "Value: $value"
    else
        print_info "Value: ********** (SecureString)"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    # Validate
    if [ -z "$PARAM_NAME" ]; then
        print_header "Setup Parameter Store"
        print_error "Parameter name is required"
        echo ""
        echo "Usage: $0 PARAM_NAME PARAM_VALUE [OPTIONS]"
        echo "       $0 PARAM_NAME --delete"
        echo ""
        echo "Run '$0 --help' for more information"
        exit 1
    fi

    if ! validate_param_name "$PARAM_NAME"; then
        exit 1
    fi

    print_header "Setup Parameter Store"

    # Prerequisites
    print_section "Prerequisites"

    if ! require_aws_cli; then
        return 1
    fi
    print_success "AWS CLI configured"
    print_info "Region: $REGION"

    # Delete mode
    if [ "$DELETE_MODE" = true ]; then
        delete_parameter "$PARAM_NAME"
        return $?
    fi

    # Create/Update mode - need value
    if [ -z "$PARAM_VALUE" ]; then
        print_error "Parameter value is required"
        print_info "Provide value as argument or use --stdin"
        exit 1
    fi

    # Validate type
    case "$PARAM_TYPE" in
        String|StringList|SecureString)
            ;;
        *)
            print_error "Invalid type: $PARAM_TYPE"
            print_info "Valid types: String, StringList, SecureString"
            exit 1
            ;;
    esac

    # Create/Update
    print_section "Parameter Configuration"
    print_info "Name: $PARAM_NAME"
    print_info "Type: $PARAM_TYPE"
    if [ -n "$PARAM_DESC" ]; then
        print_info "Description: $PARAM_DESC"
    fi

    if [ "$PARAM_TYPE" = "SecureString" ]; then
        print_info "Value: ********** (hidden)"
    else
        # Truncate long values for display
        if [ ${#PARAM_VALUE} -gt 50 ]; then
            print_info "Value: ${PARAM_VALUE:0:50}..."
        else
            print_info "Value: $PARAM_VALUE"
        fi
    fi

    echo ""

    if create_parameter "$PARAM_NAME" "$PARAM_VALUE" "$PARAM_TYPE" "$PARAM_DESC"; then
        echo ""
        show_parameter_info "$PARAM_NAME"
        echo ""
        print_success "Parameter Store setup complete!"
        return 0
    else
        return 1
    fi
}

main "$@"
exit $?
