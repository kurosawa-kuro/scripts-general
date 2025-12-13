#!/bin/bash
# =============================================================================
# Show AWS Secrets Manager Secret
# =============================================================================
# Purpose: Display secret details and optionally retrieve the value
# Usage:
#   ./secrets-show.sh SECRET_NAME
#   ./secrets-show.sh SECRET_NAME --value    # Show actual value
#   ./secrets-show.sh --list                 # List all secrets
#   ./secrets-show.sh --help
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
SHOW_VALUE="${2:-}"
REGION="$(aws_get_region)"

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Show AWS Secrets Manager Secret"
    echo ""
    echo "Usage:"
    echo "  $0 SECRET_NAME           # Show secret metadata"
    echo "  $0 SECRET_NAME --value   # Show actual secret value"
    echo "  $0 SECRET_NAME --json    # Output value as JSON"
    echo "  $0 --list                # List all secrets"
    echo "  $0 --help                # Show this help"
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

    echo ""
    local count=$(echo "$secrets" | jq 'length')
    print_info "Total: $count secrets"
}

show_secret() {
    local name="$1"
    local show_value="$2"

    # Check if secret exists
    if ! secrets_exists "$name" "$REGION"; then
        print_error "Secret '$name' not found in $REGION"
        return 1
    fi

    # Get secret metadata
    local info=$(secrets_describe "$name" "$REGION")

    if [ -z "$info" ]; then
        print_error "Failed to get secret information"
        return 1
    fi

    # Handle --json output
    if [ "$show_value" = "--json" ]; then
        local value=$(secrets_get_value "$name" "$REGION")
        echo "$value"
        return 0
    fi

    print_header "Secret: $name"

    # Parse metadata
    local arn=$(echo "$info" | jq -r '.ARN')
    local description=$(echo "$info" | jq -r '.Description // "N/A"')
    local created=$(echo "$info" | jq -r '.CreatedDate')
    local modified=$(echo "$info" | jq -r '.LastChangedDate // "N/A"')
    local rotation_enabled=$(echo "$info" | jq -r '.RotationEnabled // false')
    local deleted=$(echo "$info" | jq -r '.DeletedDate // empty')

    print_section "Metadata"
    echo "  Name:        $name"
    echo "  ARN:         $arn"
    echo "  Description: $description"
    echo "  Created:     $created"
    echo "  Modified:    $modified"
    echo "  Rotation:    $rotation_enabled"

    if [ -n "$deleted" ]; then
        print_warning "Scheduled for deletion: $deleted"
    fi

    # Tags
    local tags=$(echo "$info" | jq -r '.Tags // []')
    if [ "$tags" != "[]" ]; then
        print_section "Tags"
        echo "$tags" | jq -r '.[] | "  \(.Key): \(.Value)"'
    fi

    # Versions
    local versions=$(echo "$info" | jq -r '.VersionIdsToStages | to_entries | .[0:5]')
    if [ -n "$versions" ] && [ "$versions" != "[]" ]; then
        print_section "Versions (latest 5)"
        echo "$versions" | jq -r '.[] | "  \(.key | .[0:32])... -> \(.value | join(", "))"'
    fi

    # Show value if requested
    if [ "$show_value" = "--value" ] || [ "$show_value" = "-v" ]; then
        print_section "Secret Value"

        local value=$(secrets_get_value "$name" "$REGION")

        if [ -z "$value" ]; then
            print_error "Failed to retrieve secret value"
            return 1
        fi

        # Check if it's JSON
        if echo "$value" | jq . &>/dev/null; then
            echo "$value" | jq .
        else
            echo "$value"
        fi
    else
        echo ""
        print_info "Use --value flag to show actual secret value"
    fi

    echo ""
    print_info "Useful commands:"
    echo "  Show value:  make secrets-show NAME=$name VALUE=1"
    echo "  Update:      make secrets-create NAME=$name VALUE='new-value'"
    echo "  Delete:      make secrets-delete NAME=$name"

    return 0
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
    esac

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        return 1
    fi

    # If no secret name, list all
    if [ -z "$SECRET_NAME" ]; then
        list_secrets
        exit 0
    fi

    show_secret "$SECRET_NAME" "$SHOW_VALUE"
}

main "$@"
exit $?
