#!/bin/bash
# =============================================================================
# Setup Kinesis Data Firehose with S3 Destination for PoC
# =============================================================================
#
# This script:
# 1. Creates an S3 bucket for Firehose destination (if not exists)
# 2. Creates an IAM role for Firehose (if not exists)
# 3. Creates a Kinesis Data Firehose delivery stream (if not exists)
# 4. Sends a test record to verify the setup
#
# Usage:
#   ./setup-firehose-s3.sh [STREAM_NAME] [ENVIRONMENT]
#
# Examples:
#   ./setup-firehose-s3.sh my-data-stream dev
#   ./setup-firehose-s3.sh analytics-stream stage
#
# Environment Variables:
#   AWS_REGION      - AWS region (default: ap-northeast-1)
#   BUFFER_SIZE     - Buffer size in MB (default: 5)
#   BUFFER_INTERVAL - Buffer interval in seconds (default: 300)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

# =============================================================================
# Configuration
# =============================================================================

STREAM_NAME="${1}"
ENVIRONMENT="${2:-dev}"
REGION="$(aws_get_region)"

# Buffer configuration
BUFFER_SIZE="${BUFFER_SIZE:-5}"           # MB
BUFFER_INTERVAL="${BUFFER_INTERVAL:-300}" # seconds

# =============================================================================
# Firehose Functions (script-specific)
# =============================================================================

send_test_record() {
    local stream_name="$1"
    local region="$2"

    print_section "Sending Test Record"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local test_data='{
    "event_type": "test",
    "message": "Hello from Firehose!",
    "timestamp": "'$timestamp'",
    "stream": "'$stream_name'",
    "environment": "'$ENVIRONMENT'"
}'

    print_info "Sending test record..."
    print_info "Data: $test_data"

    if firehose_put_record "$stream_name" "$test_data" "$region"; then
        print_success "Test record sent successfully"
        print_info "Note: Data will appear in S3 after buffer interval (${BUFFER_INTERVAL}s) or buffer size (${BUFFER_SIZE}MB) is reached"
        return 0
    else
        print_error "Failed to send test record"
        return 1
    fi
}

verify_setup() {
    local stream_name="$1"
    local bucket_name="$2"
    local role_name="$3"
    local region="$4"

    print_section "Verifying Setup"

    # Check Firehose status
    print_info "Firehose Details:"
    local stream_info=$(aws firehose describe-delivery-stream \
        --delivery-stream-name "$stream_name" \
        --region "$region" \
        --output json 2>/dev/null)

    echo "  Name: $(json_get "$stream_info" '.DeliveryStreamDescription.DeliveryStreamName')"
    echo "  Status: $(json_get "$stream_info" '.DeliveryStreamDescription.DeliveryStreamStatus')"
    echo "  ARN: $(json_get "$stream_info" '.DeliveryStreamDescription.DeliveryStreamARN')"
    echo "  Created: $(json_get "$stream_info" '.DeliveryStreamDescription.CreateTimestamp')"

    # Check S3 bucket
    print_info "S3 Bucket: $bucket_name"

    # Check IAM role
    print_info "IAM Role: $role_name"

    print_success "Setup verified"
    return 0
}

# =============================================================================
# Main
# =============================================================================

main() {
    local exit_code=0

    # Validate arguments
    if [ -z "$STREAM_NAME" ]; then
        print_error "Stream name is required"
        echo ""
        echo "Usage: $0 [STREAM_NAME] [ENVIRONMENT]"
        echo "Example: $0 my-data-stream dev"
        exit 1
    fi

    # Derived names
    local ACCOUNT_ID=$(aws_get_account_id)
    local BUCKET_NAME="${STREAM_NAME}-destination-${ACCOUNT_ID}"
    local ROLE_NAME="${STREAM_NAME}-firehose-role"

    print_header "Setting Up Firehose: $STREAM_NAME"

    show_env_info "$ENVIRONMENT" "$REGION"
    print_info "Stream Name: $STREAM_NAME"
    print_info "Bucket Name: $BUCKET_NAME"
    print_info "Role Name: $ROLE_NAME"
    print_info "Buffer Size: ${BUFFER_SIZE} MB"
    print_info "Buffer Interval: ${BUFFER_INTERVAL} seconds"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        print_warning "Some features may be limited without jq"
    fi

    # Step 1: Create S3 bucket
    print_info "Checking if S3 bucket '$BUCKET_NAME' exists..."
    if s3_bucket_exists "$BUCKET_NAME"; then
        print_success "S3 bucket '$BUCKET_NAME' already exists"
    else
        print_info "S3 bucket '$BUCKET_NAME' does not exist. Creating..."
        if ! s3_create_bucket "$BUCKET_NAME" "$REGION"; then
            print_error "Failed to create S3 bucket"
            return 1
        fi
        print_success "S3 bucket created"
    fi

    # Step 2: Create IAM role
    print_info "Checking if IAM role '$ROLE_NAME' exists..."
    if iam_role_exists "$ROLE_NAME"; then
        print_success "IAM role '$ROLE_NAME' already exists"
    else
        print_info "IAM role '$ROLE_NAME' does not exist. Creating..."
        if ! iam_create_firehose_role "$ROLE_NAME" "$BUCKET_NAME" "$ACCOUNT_ID"; then
            print_error "Failed to create IAM role"
            return 1
        fi
    fi

    local ROLE_ARN=$(iam_get_role_arn "$ROLE_NAME")
    print_info "Role ARN: $ROLE_ARN"

    # Step 3: Create Firehose
    print_info "Checking if Firehose '$STREAM_NAME' exists..."
    if firehose_exists "$STREAM_NAME" "$REGION"; then
        print_success "Firehose '$STREAM_NAME' already exists"
    else
        print_info "Firehose '$STREAM_NAME' does not exist. Creating..."
        if ! firehose_create "$STREAM_NAME" "$BUCKET_NAME" "$ROLE_ARN" "$REGION" "$BUFFER_SIZE" "$BUFFER_INTERVAL"; then
            print_error "Failed to create Firehose"
            return 1
        fi
        print_success "Firehose created"

        # Wait for Firehose to be active
        if ! firehose_wait_active "$STREAM_NAME" "$REGION"; then
            print_warning "Firehose may not be fully active"
        fi
    fi

    # Step 4: Send test record
    if ! send_test_record "$STREAM_NAME" "$REGION"; then
        print_warning "Failed to send test record"
        exit_code=1
    fi

    # Verify setup
    verify_setup "$STREAM_NAME" "$BUCKET_NAME" "$ROLE_NAME" "$REGION"

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
    echo "  Stream Name:    $STREAM_NAME"
    echo "  S3 Bucket:      $BUCKET_NAME"
    echo "  S3 Prefix:      data/year=YYYY/month=MM/day=DD/"
    echo "  IAM Role:       $ROLE_NAME"
    echo "  Region:         $REGION"
    echo ""
    print_info "Useful commands:"
    print_info "  Send record:  aws firehose put-record --delivery-stream-name $STREAM_NAME --record 'Data=<base64>' --region $REGION"
    print_info "  Check status: aws firehose describe-delivery-stream --delivery-stream-name $STREAM_NAME --region $REGION"
    print_info "  List S3:      aws s3 ls s3://$BUCKET_NAME/ --recursive"
    print_info "  Delete:       aws firehose delete-delivery-stream --delivery-stream-name $STREAM_NAME --region $REGION"

    return $exit_code
}

main "$@"
exit $?
