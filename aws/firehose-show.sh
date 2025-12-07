#!/bin/bash
# =============================================================================
# Check Kinesis Data Firehose
# =============================================================================
#
# This script:
# 1. Shows delivery stream information
# 2. Shows destination configuration
# 3. Shows buffer settings and status
#
# Usage:
#   ./firehose-show.sh [STREAM_NAME]
#   ./firehose-show.sh --list
#
# Examples:
#   ./firehose-show.sh my-stream
#   ./firehose-show.sh --list
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

STREAM_NAME="${1}"
REGION="$(aws_get_region)"

# =============================================================================
# Functions
# =============================================================================

list_streams() {
    print_section "Firehose Delivery Streams"

    local streams=$(aws firehose list-delivery-streams --region "$REGION" --output json 2>/dev/null)

    if [ -z "$streams" ]; then
        print_info "No delivery streams found"
        return 0
    fi

    local count=$(echo "$streams" | jq -r '.DeliveryStreamNames | length')

    if [ "$count" -eq 0 ]; then
        print_info "No delivery streams found"
        return 0
    fi

    print_success "Found $count stream(s)"
    echo ""

    printf "  %-40s %-12s %s\n" "STREAM NAME" "STATUS" "TYPE"
    printf "  %-40s %-12s %s\n" "-----------" "------" "----"

    for name in $(echo "$streams" | jq -r '.DeliveryStreamNames[]'); do
        local info=$(aws firehose describe-delivery-stream \
            --delivery-stream-name "$name" \
            --region "$REGION" \
            --output json 2>/dev/null)

        local status=$(echo "$info" | jq -r '.DeliveryStreamDescription.DeliveryStreamStatus')
        local type=$(echo "$info" | jq -r '.DeliveryStreamDescription.DeliveryStreamType')

        printf "  %-40s %-12s %s\n" "$name" "$status" "$type"
    done
}

show_stream_info() {
    local stream_name="$1"

    print_section "Stream Information"

    local info=$(aws firehose describe-delivery-stream \
        --delivery-stream-name "$stream_name" \
        --region "$REGION" \
        --output json 2>/dev/null)

    if [ -z "$info" ] || echo "$info" | grep -q "ResourceNotFoundException"; then
        print_error "Stream '$stream_name' not found"
        return 1
    fi

    local stream_arn=$(echo "$info" | jq -r '.DeliveryStreamDescription.DeliveryStreamARN')
    local stream_status=$(echo "$info" | jq -r '.DeliveryStreamDescription.DeliveryStreamStatus')
    local stream_type=$(echo "$info" | jq -r '.DeliveryStreamDescription.DeliveryStreamType')
    local created_at=$(echo "$info" | jq -r '.DeliveryStreamDescription.CreateTimestamp')
    local version_id=$(echo "$info" | jq -r '.DeliveryStreamDescription.VersionId')

    echo "  Name:           $stream_name"
    echo "  ARN:            $stream_arn"
    echo "  Status:         $stream_status"
    echo "  Type:           $stream_type"
    echo "  Created:        $created_at"
    echo "  Version:        $version_id"

    # Store info for later use
    echo "$info"
}

show_destination() {
    local stream_info="$1"

    print_section "Destination Configuration"

    # Check for S3 destination
    local s3_dest=$(echo "$stream_info" | jq -r '.DeliveryStreamDescription.Destinations[0].ExtendedS3DestinationDescription // empty')

    if [ -n "$s3_dest" ]; then
        local bucket_arn=$(echo "$s3_dest" | jq -r '.BucketARN')
        local prefix=$(echo "$s3_dest" | jq -r '.Prefix // "N/A"')
        local error_prefix=$(echo "$s3_dest" | jq -r '.ErrorOutputPrefix // "N/A"')
        local compression=$(echo "$s3_dest" | jq -r '.CompressionFormat')
        local role_arn=$(echo "$s3_dest" | jq -r '.RoleARN')

        echo "  Type:           Extended S3"
        echo "  Bucket ARN:     $bucket_arn"
        echo "  Prefix:         $prefix"
        echo "  Error Prefix:   $error_prefix"
        echo "  Compression:    $compression"
        echo "  Role ARN:       $role_arn"
        return 0
    fi

    # Check for basic S3 destination
    local basic_s3=$(echo "$stream_info" | jq -r '.DeliveryStreamDescription.Destinations[0].S3DestinationDescription // empty')

    if [ -n "$basic_s3" ]; then
        local bucket_arn=$(echo "$basic_s3" | jq -r '.BucketARN')
        local prefix=$(echo "$basic_s3" | jq -r '.Prefix // "N/A"')
        local compression=$(echo "$basic_s3" | jq -r '.CompressionFormat')

        echo "  Type:           S3"
        echo "  Bucket ARN:     $bucket_arn"
        echo "  Prefix:         $prefix"
        echo "  Compression:    $compression"
        return 0
    fi

    # Check for Redshift destination
    local redshift=$(echo "$stream_info" | jq -r '.DeliveryStreamDescription.Destinations[0].RedshiftDestinationDescription // empty')

    if [ -n "$redshift" ]; then
        local cluster=$(echo "$redshift" | jq -r '.ClusterJDBCURL')
        echo "  Type:           Redshift"
        echo "  Cluster:        $cluster"
        return 0
    fi

    print_info "Unknown destination type"
}

show_buffer_settings() {
    local stream_info="$1"

    print_section "Buffer Settings"

    # Get buffering hints from S3 destination
    local buffering=$(echo "$stream_info" | jq -r '.DeliveryStreamDescription.Destinations[0].ExtendedS3DestinationDescription.BufferingHints // .DeliveryStreamDescription.Destinations[0].S3DestinationDescription.BufferingHints // empty')

    if [ -n "$buffering" ]; then
        local size_mb=$(echo "$buffering" | jq -r '.SizeInMBs')
        local interval_sec=$(echo "$buffering" | jq -r '.IntervalInSeconds')

        echo "  Buffer Size:    ${size_mb} MB"
        echo "  Buffer Interval: ${interval_sec} seconds"
    else
        print_info "Buffer settings not available"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Handle --list flag
    if [ "$STREAM_NAME" = "--list" ] || [ "$STREAM_NAME" = "-l" ]; then
        print_header "Firehose Delivery Streams"

        if ! require_aws_cli; then
            return 1
        fi

        list_streams
        return 0
    fi

    # Validate arguments
    if [ -z "$STREAM_NAME" ]; then
        print_error "Stream name is required"
        echo ""
        echo "Usage: $0 [STREAM_NAME]"
        echo "       $0 --list"
        echo ""
        echo "Example: $0 my-stream"
        exit 1
    fi

    print_header "Firehose Stream: $STREAM_NAME"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        print_error "jq is required for this script"
        return 1
    fi

    # Show stream info and capture output
    local stream_info
    stream_info=$(show_stream_info "$STREAM_NAME")
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        return 1
    fi

    # Parse the JSON from the output (last line contains the JSON)
    local json_info=$(aws firehose describe-delivery-stream \
        --delivery-stream-name "$STREAM_NAME" \
        --region "$REGION" \
        --output json 2>/dev/null)

    # Show destination
    show_destination "$json_info"

    # Show buffer settings
    show_buffer_settings "$json_info"

    # Summary
    echo ""
    print_info "Useful commands:"
    print_info "  Put record:   aws firehose put-record --delivery-stream-name $STREAM_NAME --record 'Data=...'"
    print_info "  Update:       aws firehose update-destination --delivery-stream-name $STREAM_NAME ..."
    print_info "  Delete:       aws firehose delete-delivery-stream --delivery-stream-name $STREAM_NAME"

    return 0
}

main "$@"
exit $?
