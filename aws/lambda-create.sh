#!/bin/bash
# =============================================================================
# Create AWS Lambda Function
# =============================================================================
# Purpose: Create a Lambda function from a ZIP file or inline code
# Usage:
#   ./lambda-create.sh FUNCTION_NAME [ZIP_FILE]
#   ./lambda-create.sh my-func ./function.zip
#   ./lambda-create.sh my-func --inline          # Create sample function
#   ./lambda-create.sh --help
#
# Environment Variables:
#   AWS_REGION        - AWS region (default: ap-northeast-1)
#   LAMBDA_RUNTIME    - Runtime (default: python3.12)
#   LAMBDA_HANDLER    - Handler (default: index.handler)
#   LAMBDA_MEMORY     - Memory in MB (default: 128)
#   LAMBDA_TIMEOUT    - Timeout in seconds (default: 30)
#   LAMBDA_ROLE_ARN   - IAM role ARN (creates one if not specified)
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
ZIP_FILE="${2:-}"
REGION="$(aws_get_region)"

LAMBDA_RUNTIME="${LAMBDA_RUNTIME:-python3.12}"
LAMBDA_HANDLER="${LAMBDA_HANDLER:-index.handler}"
LAMBDA_MEMORY="${LAMBDA_MEMORY:-128}"
LAMBDA_TIMEOUT="${LAMBDA_TIMEOUT:-30}"
LAMBDA_ROLE_ARN="${LAMBDA_ROLE_ARN:-}"

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "Create AWS Lambda Function"
    echo ""
    echo "Usage:"
    echo "  $0 FUNCTION_NAME [ZIP_FILE]"
    echo "  $0 my-func ./function.zip      # Create from ZIP"
    echo "  $0 my-func --inline            # Create sample function"
    echo "  $0 my-func --update ./new.zip  # Update existing function"
    echo "  $0 --list                      # List all functions"
    echo "  $0 --help                      # Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION       Region (default: ap-northeast-1)"
    echo "  LAMBDA_RUNTIME   Runtime (default: python3.12)"
    echo "  LAMBDA_HANDLER   Handler (default: index.handler)"
    echo "  LAMBDA_MEMORY    Memory MB (default: 128)"
    echo "  LAMBDA_TIMEOUT   Timeout sec (default: 30)"
    echo "  LAMBDA_ROLE_ARN  IAM role ARN"
    echo ""
    echo "Supported Runtimes:"
    echo "  python3.12, python3.11, python3.10, python3.9"
    echo "  nodejs20.x, nodejs18.x"
    echo "  java21, java17, java11"
    echo "  go1.x"
}

create_sample_function() {
    local tmp_dir=$(mktemp -d)
    local zip_file="$tmp_dir/function.zip"

    print_info "Creating sample Python function..."

    # Create index.py
    cat > "$tmp_dir/index.py" <<'EOF'
import json

def handler(event, context):
    """Sample Lambda handler"""
    print(f"Received event: {json.dumps(event)}")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from Lambda!',
            'input': event
        })
    }
EOF

    # Create ZIP
    (cd "$tmp_dir" && zip -q function.zip index.py)

    echo "$zip_file"
}

ensure_role() {
    if [ -n "$LAMBDA_ROLE_ARN" ]; then
        echo "$LAMBDA_ROLE_ARN"
        return 0
    fi

    local role_name="lambda-${FUNCTION_NAME}-role"

    if iam_role_exists "$role_name"; then
        print_info "Using existing role: $role_name"
    else
        iam_create_lambda_role "$role_name"
        print_success "Created role: $role_name"
    fi

    iam_get_role_arn "$role_name"
}

list_functions() {
    print_header "Lambda Functions"

    local functions=$(lambda_list "$REGION")

    if [ -z "$functions" ] || [ "$functions" = "[]" ]; then
        print_info "No Lambda functions found in $REGION"
        return 0
    fi

    echo "$functions" | jq -r '.[] | "  \(.Name) [\(.Runtime)] \(.Memory)MB \(.Timeout)s"'
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

    # Validate arguments
    if [ -z "$FUNCTION_NAME" ]; then
        print_error "Function name is required"
        echo ""
        print_usage
        exit 1
    fi

    print_header "Create Lambda Function: $FUNCTION_NAME"

    show_env_info "lambda" "$REGION"
    print_info "Runtime: $LAMBDA_RUNTIME"
    print_info "Handler: $LAMBDA_HANDLER"
    print_info "Memory: ${LAMBDA_MEMORY}MB"
    print_info "Timeout: ${LAMBDA_TIMEOUT}s"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        return 1
    fi

    # Handle --update flag
    if [ "$ZIP_FILE" = "--update" ]; then
        local new_zip="${3:-}"
        if [ -z "$new_zip" ] || [ ! -f "$new_zip" ]; then
            print_error "ZIP file required for update"
            exit 1
        fi

        if ! lambda_exists "$FUNCTION_NAME" "$REGION"; then
            print_error "Function '$FUNCTION_NAME' does not exist"
            exit 1
        fi

        print_section "Updating Function Code"
        if lambda_update_code "$FUNCTION_NAME" "$new_zip" "$REGION" > /dev/null; then
            print_success "Function code updated"
        else
            print_error "Failed to update function"
            exit 1
        fi

        exit 0
    fi

    # Check if function exists
    if lambda_exists "$FUNCTION_NAME" "$REGION"; then
        print_warning "Function '$FUNCTION_NAME' already exists"

        local info=$(lambda_get_info "$FUNCTION_NAME" "$REGION")
        local runtime=$(json_get "$info" '.Configuration.Runtime')
        local modified=$(json_get "$info" '.Configuration.LastModified')

        print_info "Runtime: $runtime"
        print_info "Modified: $modified"

        if ! confirm "Update existing function?"; then
            print_info "Cancelled"
            exit 0
        fi

        # Update existing function
        if [ -z "$ZIP_FILE" ] || [ "$ZIP_FILE" = "--inline" ]; then
            ZIP_FILE=$(create_sample_function)
        fi

        if lambda_update_code "$FUNCTION_NAME" "$ZIP_FILE" "$REGION" > /dev/null; then
            print_success "Function updated"
        else
            print_error "Failed to update function"
            exit 1
        fi

        exit 0
    fi

    # Prepare ZIP file
    print_section "Preparing Code"

    local tmp_zip=""
    if [ -z "$ZIP_FILE" ] || [ "$ZIP_FILE" = "--inline" ]; then
        ZIP_FILE=$(create_sample_function)
        tmp_zip="$ZIP_FILE"
        print_success "Created sample function"
    elif [ ! -f "$ZIP_FILE" ]; then
        print_error "ZIP file not found: $ZIP_FILE"
        exit 1
    fi

    print_info "ZIP file: $ZIP_FILE"

    # Ensure IAM role exists
    print_section "IAM Role"

    local role_arn=$(ensure_role)
    if [ -z "$role_arn" ]; then
        print_error "Failed to get/create IAM role"
        exit 1
    fi

    print_info "Role ARN: $role_arn"

    # Create Lambda function
    print_section "Creating Function"

    local result=$(lambda_create \
        "$FUNCTION_NAME" \
        "$LAMBDA_RUNTIME" \
        "$LAMBDA_HANDLER" \
        "$role_arn" \
        "$ZIP_FILE" \
        "$REGION" \
        "$LAMBDA_MEMORY" \
        "$LAMBDA_TIMEOUT")

    if [ -z "$result" ]; then
        print_error "Failed to create Lambda function"
        exit 1
    fi

    local function_arn=$(echo "$result" | jq -r '.FunctionArn')
    print_success "Function created"

    # Cleanup temp files
    if [ -n "$tmp_zip" ]; then
        rm -rf "$(dirname "$tmp_zip")"
    fi

    # Summary
    echo ""
    print_success "Lambda function created successfully!"

    echo ""
    print_section "Function Information"
    echo "  Name:    $FUNCTION_NAME"
    echo "  ARN:     $function_arn"
    echo "  Runtime: $LAMBDA_RUNTIME"
    echo "  Handler: $LAMBDA_HANDLER"
    echo "  Memory:  ${LAMBDA_MEMORY}MB"
    echo "  Timeout: ${LAMBDA_TIMEOUT}s"

    echo ""
    print_info "Useful commands:"
    echo "  Invoke:  make lambda-invoke NAME=$FUNCTION_NAME"
    echo "  Logs:    make lambda-logs NAME=$FUNCTION_NAME"
    echo "  Show:    make lambda-show NAME=$FUNCTION_NAME"

    return 0
}

main "$@"
exit $?
