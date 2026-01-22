#!/bin/bash
# =============================================================================
# Create AWS Secrets Manager Secret
# =============================================================================
# Purpose: Create or update a secret in AWS Secrets Manager
# Usage:
#   ./secrets-create.sh SECRET_NAME SECRET_VALUE
#   ./secrets-create.sh my-secret "my-secret-value"
#   ./secrets-create.sh my-db-creds '{"username":"admin","password":"pass123"}'
#   ./secrets-create.sh my-secret --from-file ./secret.txt
#   ./secrets-create.sh --help
#
# Environment Variables:
#   AWS_REGION   - AWS region (default: ap-northeast-1)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

# =============================================================================
# Configuration
# =============================================================================

SECRET_NAME="${1:-}"
SECRET_VALUE="${2:-}"
REGION="$(aws_get_region)"

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Create AWS Secrets Manager Secret"
    echo ""
    echo "Usage:"
    echo "  $0 SECRET_NAME SECRET_VALUE"
    echo "  $0 SECRET_NAME --from-file FILE"
    echo "  $0 SECRET_NAME --from-env VAR_NAME"
    echo "  $0 --list                           # List all secrets"
    echo "  $0 --delete SECRET_NAME             # Delete a secret"
    echo "  $0 --help                           # Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 my-api-key 'sk-12345'"
    echo "  $0 db/prod/creds '{\"user\":\"admin\",\"pass\":\"secret\"}'"
    echo "  $0 my-cert --from-file ./cert.pem"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION   Region (default: ap-northeast-1)"
}

list_secrets() {
    print_header "Secrets Manager Secrets"

    print_info "Region: $REGION"
    echo ""

    local secrets=$(secrets_list "$REGION")

    if [ -z "$secrets" ] || [ "$secrets" = "[]" ] || [ "$secrets" = "null" ]; then
        print_info "No secrets found"
        return 0
    fi

    printf "  %-40s %-30s %s\n" "NAME" "DESCRIPTION" "MODIFIED"
    printf "  %-40s %-30s %s\n" "----" "-----------" "--------"

    echo "$secrets" | jq -r '.[] | "  \(.Name | .[0:40]) \(.Description // "N/A" | .[0:30]) \(.Modified | .[0:19] // "N/A")"'
}

delete_secret() {
    local name="$1"
    local force="${2:-false}"

    print_header "Delete Secret: $name"

    if ! secrets_exists "$name" "$REGION"; then
        print_warning "Secret '$name' does not exist"
        return 0
    fi

    print_warning "This will schedule the secret for deletion"

    if [ "$force" = true ]; then
        print_warning "Force delete: Secret will be immediately deleted (unrecoverable)"
    else
        print_info "Secret will be recoverable for 30 days"
    fi

    if ! confirm "Delete secret '$name'?"; then
        print_info "Cancelled"
        return 0
    fi

    if secrets_delete "$name" "$REGION" "$force"; then
        print_success "Secret deleted"
    else
        print_error "Failed to delete secret"
        return 1
    fi
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
        --list|-l)
            list_secrets
            exit 0
            ;;
        --delete|-d)
            shift
            delete_secret "${1:-}" "${2:-false}"
            exit $?
            ;;
    esac

    # Validate arguments
    if [ -z "$SECRET_NAME" ]; then
        print_error "Secret name is required"
        echo ""
        print_usage
        exit 1
    fi

    print_header "Create Secret: $SECRET_NAME"

    show_env_info "secrets" "$REGION"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        return 1
    fi

    # Handle --from-file
    if [ "$SECRET_VALUE" = "--from-file" ]; then
        local file="${3:-}"
        if [ -z "$file" ] || [ ! -f "$file" ]; then
            print_error "File not found: $file"
            exit 1
        fi
        SECRET_VALUE=$(cat "$file")
        print_info "Reading secret from file: $file"
    fi

    # Handle --from-env
    if [ "$SECRET_VALUE" = "--from-env" ]; then
        local var_name="${3:-}"
        if [ -z "$var_name" ]; then
            print_error "Environment variable name required"
            exit 1
        fi
        SECRET_VALUE="${!var_name}"
        if [ -z "$SECRET_VALUE" ]; then
            print_error "Environment variable '$var_name' is empty or not set"
            exit 1
        fi
        print_info "Reading secret from environment: $var_name"
    fi

    # Validate secret value
    if [ -z "$SECRET_VALUE" ]; then
        print_error "Secret value is required"
        echo ""
        print_usage
        exit 1
    fi

    # Check if it's JSON
    local is_json=false
    if echo "$SECRET_VALUE" | jq . &>/dev/null; then
        is_json=true
        print_info "Secret type: JSON"
    else
        print_info "Secret type: String"
    fi

    # Show masked value
    local value_preview
    if [ "$is_json" = true ]; then
        value_preview=$(echo "$SECRET_VALUE" | jq -r 'to_entries | .[0:3] | .[] | "\(.key): ****"')
    else
        local len=${#SECRET_VALUE}
        if [ $len -gt 8 ]; then
            value_preview="${SECRET_VALUE:0:4}****${SECRET_VALUE: -4}"
        else
            value_preview="****"
        fi
    fi
    print_info "Value preview:"
    echo "$value_preview" | while read -r line; do
        echo "    $line"
    done

    # Check if secret exists
    if secrets_exists "$SECRET_NAME" "$REGION"; then
        print_warning "Secret '$SECRET_NAME' already exists"

        local info=$(secrets_describe "$SECRET_NAME" "$REGION")
        local created=$(echo "$info" | jq -r '.CreatedDate')
        local modified=$(echo "$info" | jq -r '.LastChangedDate')

        print_info "Created: $created"
        print_info "Modified: $modified"

        if ! confirm "Update existing secret?"; then
            print_info "Cancelled"
            exit 0
        fi

        # Update existing secret
        print_section "Updating Secret"

        if secrets_update "$SECRET_NAME" "$SECRET_VALUE" "$REGION" > /dev/null; then
            print_success "Secret updated"
        else
            print_error "Failed to update secret"
            exit 1
        fi
    else
        # Create new secret
        print_section "Creating Secret"

        local result=$(secrets_create "$SECRET_NAME" "$SECRET_VALUE" "$REGION")

        if [ -z "$result" ]; then
            print_error "Failed to create secret"
            exit 1
        fi

        local arn=$(echo "$result" | jq -r '.ARN')
        print_success "Secret created"
        print_info "ARN: $arn"
    fi

    # Summary
    echo ""
    print_success "Secret operation completed!"

    echo ""
    print_info "Useful commands:"
    echo "  Show:   make secrets-show NAME=$SECRET_NAME"
    echo "  List:   make secrets-list"
    echo "  Delete: make secrets-delete NAME=$SECRET_NAME"
    echo ""
    print_info "SDK usage:"
    echo "  Python: client.get_secret_value(SecretId='$SECRET_NAME')"
    echo "  Node:   client.getSecretValue({SecretId: '$SECRET_NAME'})"

    return 0
}

main "$@"
exit $?
