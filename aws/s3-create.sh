#!/bin/bash
# =============================================================================
# Setup S3 Bucket for PoC
# =============================================================================
#
# This script:
# 1. Checks if S3 bucket exists
# 2. Creates the bucket if it doesn't exist
# 3. Uploads sample files for testing
#
# Usage:
#   ./setup-s3.sh [BUCKET_NAME] [ENVIRONMENT]
#
# Examples:
#   ./setup-s3.sh my-poc-bucket dev
#   ./setup-s3.sh my-app-data-bucket stage
#
# Environment Variables:
#   AWS_REGION - AWS region (default: ap-northeast-1)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

# =============================================================================
# Configuration
# =============================================================================

BUCKET_NAME="${1}"
ENVIRONMENT="${2:-dev}"
REGION="$(aws_get_region)"

# =============================================================================
# S3 Functions
# =============================================================================

has_sample_files() {
    local bucket_name="$1"

    local count=$(aws s3 ls "s3://$bucket_name/sample/" 2>/dev/null | wc -l)

    if [ "$count" -gt 0 ]; then
        return 0  # Has files
    else
        return 1  # No files
    fi
}

upload_sample_files() {
    local bucket_name="$1"

    print_section "Uploading Sample Files"

    local current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create sample text file
    local hello_content="Hello from S3!
This is a sample file for PoC testing.
Created at: $current_timestamp
Bucket: $bucket_name
Environment: $ENVIRONMENT"

    print_info "Uploading sample/hello.txt..."
    if s3_upload_string "$bucket_name" "sample/hello.txt" "$hello_content" "text/plain"; then
        print_success "Uploaded sample/hello.txt"
    else
        print_error "Failed to upload sample/hello.txt"
        return 1
    fi

    # Create sample JSON file
    local json_content='{
  "name": "poc-config",
  "version": "1.0.0",
  "environment": "'$ENVIRONMENT'",
  "created_at": "'$current_timestamp'",
  "settings": {
    "debug": true,
    "log_level": "info",
    "max_retries": 3
  },
  "features": {
    "feature_a": true,
    "feature_b": false,
    "feature_c": true
  }
}'

    print_info "Uploading sample/config.json..."
    if s3_upload_string "$bucket_name" "sample/config.json" "$json_content" "application/json"; then
        print_success "Uploaded sample/config.json"
    else
        print_error "Failed to upload sample/config.json"
        return 1
    fi

    # Create sample CSV file
    local csv_content="id,name,value,created_at
1,item_a,100,$current_timestamp
2,item_b,200,$current_timestamp
3,item_c,300,$current_timestamp"

    print_info "Uploading sample/data.csv..."
    if s3_upload_string "$bucket_name" "sample/data.csv" "$csv_content" "text/csv"; then
        print_success "Uploaded sample/data.csv"
    else
        print_error "Failed to upload sample/data.csv"
        return 1
    fi

    return 0
}

verify_files() {
    local bucket_name="$1"

    print_section "Verifying Uploaded Files"

    print_info "Files in bucket:"
    aws s3 ls "s3://$bucket_name/" --recursive 2>/dev/null | while read -r line; do
        echo "  $line"
    done

    local count=$(aws s3 ls "s3://$bucket_name/" --recursive 2>/dev/null | wc -l)

    if [ "$count" -gt 0 ]; then
        print_success "Found $count file(s) in the bucket"
        return 0
    else
        print_error "No files found in the bucket"
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    local exit_code=0

    # Validate arguments
    if [ -z "$BUCKET_NAME" ]; then
        print_error "Bucket name is required"
        echo ""
        echo "Usage: $0 [BUCKET_NAME] [ENVIRONMENT]"
        echo "Example: $0 my-poc-bucket dev"
        exit 1
    fi

    print_header "Setting Up S3 Bucket: $BUCKET_NAME"

    show_env_info "$ENVIRONMENT" "$REGION"
    print_info "Bucket Name: $BUCKET_NAME"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    # Step 1: Check if bucket exists
    if s3_bucket_exists "$BUCKET_NAME"; then
        print_success "Bucket '$BUCKET_NAME' already exists"

        # Check if sample files exist
        if has_sample_files "$BUCKET_NAME"; then
            print_success "Sample files already exist. Skipping upload."
        else
            print_info "Bucket exists but has no sample files. Uploading..."
            if ! upload_sample_files "$BUCKET_NAME"; then
                print_warning "Some file uploads failed"
                exit_code=1
            fi
        fi
    else
        print_info "Bucket '$BUCKET_NAME' does not exist. Creating..."

        # Step 2: Create bucket
        if ! s3_create_bucket "$BUCKET_NAME" "$REGION"; then
            print_error "Failed to create bucket"
            return 1
        fi
        print_success "Bucket created successfully"

        # Step 3: Configure bucket
        s3_block_public_access "$BUCKET_NAME" && print_success "Public access blocked"
        s3_enable_versioning "$BUCKET_NAME" && print_success "Versioning enabled"

        # Step 4: Upload sample files
        if ! upload_sample_files "$BUCKET_NAME"; then
            print_warning "Some file uploads failed"
            exit_code=1
        fi
    fi

    # Verify
    if ! verify_files "$BUCKET_NAME"; then
        exit_code=1
    fi

    # Summary
    echo ""
    if [ $exit_code -eq 0 ]; then
        print_success "Setup complete! All operations completed successfully."
    else
        print_warning "Setup completed with warnings. Some operations failed."
    fi

    echo ""
    print_info "Useful commands:"
    print_info "  List files: aws s3 ls s3://$BUCKET_NAME/ --recursive"
    print_info "  Get file:   aws s3 cp s3://$BUCKET_NAME/sample/hello.txt -"
    print_info "  Delete:     aws s3 rb s3://$BUCKET_NAME --force"

    return $exit_code
}

main "$@"
exit $?
