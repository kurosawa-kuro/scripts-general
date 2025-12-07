#!/bin/bash
# =============================================================================
# Check S3 Bucket
# =============================================================================
#
# This script:
# 1. Shows bucket information
# 2. Lists objects with size and modification date
# 3. Shows bucket configuration
#
# Usage:
#   ./s3-show.sh [BUCKET_NAME]
#   ./s3-show.sh --list
#
# Examples:
#   ./s3-show.sh my-bucket
#   ./s3-show.sh --list
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
REGION="$(aws_get_region)"

# =============================================================================
# Functions
# =============================================================================

list_buckets() {
    print_section "S3 Buckets"

    local buckets=$(aws s3api list-buckets --output json 2>/dev/null)

    if [ -z "$buckets" ]; then
        print_info "No buckets found"
        return 0
    fi

    local count=$(echo "$buckets" | jq -r '.Buckets | length')

    if [ "$count" -eq 0 ]; then
        print_info "No buckets found"
        return 0
    fi

    print_success "Found $count bucket(s)"
    echo ""

    printf "  %-40s %s\n" "BUCKET NAME" "CREATED"
    printf "  %-40s %s\n" "-----------" "-------"

    echo "$buckets" | jq -r '.Buckets[] | "\(.Name)\t\(.CreationDate | split("T")[0])"' | \
    while IFS=$'\t' read -r name created; do
        printf "  %-40s %s\n" "$name" "$created"
    done
}

show_bucket_info() {
    local bucket_name="$1"

    print_section "Bucket Information"

    # Check if bucket exists
    if ! s3_bucket_exists "$bucket_name"; then
        print_error "Bucket '$bucket_name' not found"
        return 1
    fi

    # Get bucket location
    local location=$(aws s3api get-bucket-location --bucket "$bucket_name" --output text 2>/dev/null)
    [ "$location" = "None" ] && location="us-east-1"

    # Get versioning status
    local versioning=$(aws s3api get-bucket-versioning --bucket "$bucket_name" --query 'Status' --output text 2>/dev/null)
    [ -z "$versioning" ] || [ "$versioning" = "None" ] && versioning="Disabled"

    # Get public access block
    local public_access="Unknown"
    if aws s3api get-public-access-block --bucket "$bucket_name" &>/dev/null; then
        local block_all=$(aws s3api get-public-access-block --bucket "$bucket_name" \
            --query 'PublicAccessBlockConfiguration.BlockPublicAcls' --output text 2>/dev/null)
        [ "$block_all" = "True" ] && public_access="Blocked" || public_access="Allowed"
    fi

    # Get encryption
    local encryption="None"
    local enc_result=$(aws s3api get-bucket-encryption --bucket "$bucket_name" 2>/dev/null)
    if [ -n "$enc_result" ]; then
        encryption=$(echo "$enc_result" | jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm // "None"')
    fi

    echo "  Name:           $bucket_name"
    echo "  Region:         $location"
    echo "  Versioning:     $versioning"
    echo "  Public Access:  $public_access"
    echo "  Encryption:     $encryption"
}

show_bucket_size() {
    local bucket_name="$1"

    print_section "Bucket Size"

    # Count objects and calculate size
    local stats=$(aws s3 ls "s3://$bucket_name" --recursive --summarize 2>/dev/null | tail -2)

    if [ -z "$stats" ]; then
        print_info "Bucket is empty"
        return 0
    fi

    local total_objects=$(echo "$stats" | grep "Total Objects" | awk '{print $3}')
    local total_size=$(echo "$stats" | grep "Total Size" | awk '{print $3}')

    # Convert size to human readable
    local size_hr="$total_size bytes"
    if [ "$total_size" -gt 1073741824 ]; then
        size_hr="$(echo "scale=2; $total_size / 1073741824" | bc) GB"
    elif [ "$total_size" -gt 1048576 ]; then
        size_hr="$(echo "scale=2; $total_size / 1048576" | bc) MB"
    elif [ "$total_size" -gt 1024 ]; then
        size_hr="$(echo "scale=2; $total_size / 1024" | bc) KB"
    fi

    echo "  Total Objects:  $total_objects"
    echo "  Total Size:     $size_hr"
}

show_objects() {
    local bucket_name="$1"
    local limit="${2:-20}"

    print_section "Objects (up to $limit)"

    local objects=$(aws s3 ls "s3://$bucket_name" --recursive 2>/dev/null | head -"$limit")

    if [ -z "$objects" ]; then
        print_info "No objects found"
        return 0
    fi

    local count=$(echo "$objects" | wc -l)
    print_success "Showing $count object(s)"
    echo ""

    printf "  %-12s %-10s %s\n" "DATE" "SIZE" "KEY"
    printf "  %-12s %-10s %s\n" "----" "----" "---"

    echo "$objects" | while read -r date time size key; do
        # Convert size to human readable
        local size_hr="$size"
        if [ "$size" -gt 1048576 ]; then
            size_hr="$(echo "scale=1; $size / 1048576" | bc)M"
        elif [ "$size" -gt 1024 ]; then
            size_hr="$(echo "scale=1; $size / 1024" | bc)K"
        fi
        printf "  %-12s %-10s %s\n" "$date" "$size_hr" "$key"
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Handle --list flag
    if [ "$BUCKET_NAME" = "--list" ] || [ "$BUCKET_NAME" = "-l" ]; then
        print_header "S3 Buckets"

        if ! require_aws_cli; then
            return 1
        fi

        list_buckets
        return 0
    fi

    # Validate arguments
    if [ -z "$BUCKET_NAME" ]; then
        print_error "Bucket name is required"
        echo ""
        echo "Usage: $0 [BUCKET_NAME]"
        echo "       $0 --list"
        echo ""
        echo "Example: $0 my-bucket"
        exit 1
    fi

    print_header "S3 Bucket: $BUCKET_NAME"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    # Show bucket info
    if ! show_bucket_info "$BUCKET_NAME"; then
        return 1
    fi

    # Show bucket size
    show_bucket_size "$BUCKET_NAME"

    # Show objects
    show_objects "$BUCKET_NAME"

    # Summary
    echo ""
    print_info "Useful commands:"
    print_info "  List all:   aws s3 ls s3://$BUCKET_NAME --recursive"
    print_info "  Download:   aws s3 cp s3://$BUCKET_NAME/path/file.txt ."
    print_info "  Upload:     aws s3 cp file.txt s3://$BUCKET_NAME/"
    print_info "  Delete:     aws s3 rb s3://$BUCKET_NAME --force"

    return 0
}

main "$@"
exit $?
