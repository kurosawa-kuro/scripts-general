#!/bin/bash
# =============================================================================
# Show AWS Lambda Function Details
# =============================================================================
# Purpose: Display Lambda function information and recent logs
# Usage:
#   ./lambda-show.sh FUNCTION_NAME
#   ./lambda-show.sh --list          # List all functions
#   ./lambda-show.sh --help
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

FUNCTION_NAME="${1:-}"
REGION="$(aws_get_region)"

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Show AWS Lambda Function Details"
    echo ""
    echo "Usage:"
    echo "  $0 FUNCTION_NAME     # Show function details"
    echo "  $0 --list            # List all functions"
    echo "  $0 --help            # Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION   Region (default: ap-northeast-1)"
}

list_functions() {
    print_header "Lambda Functions"

    print_info "Region: $REGION"
    echo ""

    local functions=$(lambda_list "$REGION")

    if [ -z "$functions" ] || [ "$functions" = "[]" ] || [ "$functions" = "null" ]; then
        print_info "No Lambda functions found"
        return 0
    fi

    printf "  %-30s %-15s %8s %8s %s\n" "NAME" "RUNTIME" "MEMORY" "TIMEOUT" "MODIFIED"
    printf "  %-30s %-15s %8s %8s %s\n" "----" "-------" "------" "-------" "--------"

    echo "$functions" | jq -r '.[] | "  \(.Name | .[0:30] | . + " " * (30 - length)) \(.Runtime | . + " " * (15 - length)) \(.Memory | tostring | . + " " * (8 - length)) \(.Timeout | tostring | . + " " * (8 - length)) \(.Modified | .[0:19])"'
}

show_function() {
    local name="$1"

    print_header "Lambda Function: $name"

    # Check if function exists
    if ! lambda_exists "$name" "$REGION"; then
        print_error "Function '$name' not found in $REGION"
        return 1
    fi

    # Get function details
    local info=$(lambda_get_info "$name" "$REGION")

    if [ -z "$info" ]; then
        print_error "Failed to get function information"
        return 1
    fi

    # Parse configuration
    local config=$(echo "$info" | jq '.Configuration')
    local arn=$(echo "$config" | jq -r '.FunctionArn')
    local runtime=$(echo "$config" | jq -r '.Runtime')
    local handler=$(echo "$config" | jq -r '.Handler')
    local memory=$(echo "$config" | jq -r '.MemorySize')
    local timeout=$(echo "$config" | jq -r '.Timeout')
    local code_size=$(echo "$config" | jq -r '.CodeSize')
    local modified=$(echo "$config" | jq -r '.LastModified')
    local role=$(echo "$config" | jq -r '.Role')
    local state=$(echo "$config" | jq -r '.State // "Active"')
    local description=$(echo "$config" | jq -r '.Description // "N/A"')

    # Format code size
    local code_size_kb=$((code_size / 1024))

    print_section "Configuration"
    echo "  Name:        $name"
    echo "  ARN:         $arn"
    echo "  Runtime:     $runtime"
    echo "  Handler:     $handler"
    echo "  Memory:      ${memory}MB"
    echo "  Timeout:     ${timeout}s"
    echo "  Code Size:   ${code_size_kb}KB"
    echo "  State:       $state"
    echo "  Modified:    $modified"
    echo "  Description: $description"

    print_section "IAM Role"
    echo "  $role"

    # Environment variables
    local env_vars=$(echo "$config" | jq -r '.Environment.Variables // empty')
    if [ -n "$env_vars" ] && [ "$env_vars" != "null" ]; then
        print_section "Environment Variables"
        echo "$env_vars" | jq -r 'to_entries | .[] | "  \(.key)=\(.value)"'
    fi

    # VPC configuration
    local vpc=$(echo "$config" | jq -r '.VpcConfig.VpcId // empty')
    if [ -n "$vpc" ] && [ "$vpc" != "null" ]; then
        print_section "VPC Configuration"
        echo "  VPC ID: $vpc"
        local subnets=$(echo "$config" | jq -r '.VpcConfig.SubnetIds | join(", ")')
        local sgs=$(echo "$config" | jq -r '.VpcConfig.SecurityGroupIds | join(", ")')
        echo "  Subnets: $subnets"
        echo "  Security Groups: $sgs"
    fi

    # Layers
    local layers=$(echo "$config" | jq -r '.Layers // []')
    if [ "$layers" != "[]" ]; then
        print_section "Layers"
        echo "$layers" | jq -r '.[] | "  \(.Arn)"'
    fi

    # Recent invocations (from CloudWatch)
    print_section "Recent Logs (last hour)"
    local logs=$(lambda_get_logs "$name" "$REGION" "" "10")

    if [ -z "$logs" ] || [ "$(echo "$logs" | jq -r '.events | length')" = "0" ]; then
        print_info "No recent logs found"
    else
        echo "$logs" | jq -r '.events[] | "[\(.timestamp / 1000 | strftime("%Y-%m-%d %H:%M:%S"))] \(.message | gsub("\n"; " ") | .[0:100])"' 2>/dev/null || \
        echo "$logs" | jq -r '.events[].message | .[0:100]'
    fi

    echo ""
    print_info "Useful commands:"
    echo "  Invoke:  make lambda-invoke NAME=$name PAYLOAD='{\"key\":\"value\"}'"
    echo "  Logs:    make lambda-logs NAME=$name"
    echo "  Update:  make lambda-create NAME=$name ZIP=./function.zip"

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
            list_functions
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

    # If no function name, list all
    if [ -z "$FUNCTION_NAME" ]; then
        list_functions
        exit 0
    fi

    show_function "$FUNCTION_NAME"
}

main "$@"
exit $?
