#!/bin/bash
# =============================================================================
# Setup DynamoDB Table for PoC
# =============================================================================
#
# This script:
# 1. Checks if DynamoDB table exists
# 2. Creates the table if it doesn't exist
# 3. Inserts sample data only if table exists but has no data
#
# Usage:
#   ./setup-dynamodb-table.sh [TABLE_NAME] [ENVIRONMENT]
#
# Examples:
#   ./setup-dynamodb-table.sh my-table-dev dev
#   ./setup-dynamodb-table.sh my-table-stage stage
#
# Environment Variables:
#   AWS_REGION           - AWS region (default: ap-northeast-1)
#   ATTRIBUTE_NAME       - Primary key attribute name (default: id)
#   ATTRIBUTE_TYPE       - Primary key attribute type N/S/B (default: N)
#   READ_CAPACITY_UNITS  - Read capacity units (default: 5)
#   WRITE_CAPACITY_UNITS - Write capacity units (default: 5)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

# =============================================================================
# Configuration
# =============================================================================

TABLE_NAME="${1}"
ENVIRONMENT="${2:-dev}"
REGION="$(aws_get_region)"

# Primary key configuration
ATTRIBUTE_NAME="${ATTRIBUTE_NAME:-id}"
ATTRIBUTE_TYPE="${ATTRIBUTE_TYPE:-N}"

# Throughput configuration
READ_CAPACITY_UNITS="${READ_CAPACITY_UNITS:-5}"
WRITE_CAPACITY_UNITS="${WRITE_CAPACITY_UNITS:-5}"

# =============================================================================
# DynamoDB Functions (script-specific)
# =============================================================================

has_data() {
    local table_name="$1"
    local region="$2"

    local count=$(dynamodb_scan_count "$table_name" "$region")

    if [ -n "$count" ] && [ "$count" -gt 0 ]; then
        return 0  # Data exists
    else
        return 1  # No data
    fi
}

insert_sample_data() {
    local table_name="$1"
    local region="$2"

    print_section "Inserting sample data (3 items)..."

    local current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local items=(
        "{\"id\": {\"N\": \"1\"}, \"name\": {\"S\": \"Sample Product 1\"}, \"price\": {\"N\": \"100\"}, \"description\": {\"S\": \"This is a sample product 1\"}, \"category\": {\"S\": \"basic\"}, \"created_at\": {\"S\": \"$current_timestamp\"}}"
        "{\"id\": {\"N\": \"2\"}, \"name\": {\"S\": \"Sample Product 2\"}, \"price\": {\"N\": \"200\"}, \"description\": {\"S\": \"This is a sample product 2\"}, \"category\": {\"S\": \"standard\"}, \"created_at\": {\"S\": \"$current_timestamp\"}}"
        "{\"id\": {\"N\": \"3\"}, \"name\": {\"S\": \"Sample Product 3\"}, \"price\": {\"N\": \"300\"}, \"description\": {\"S\": \"This is a sample product 3\"}, \"category\": {\"S\": \"premium\"}, \"created_at\": {\"S\": \"$current_timestamp\"}}"
    )

    local success_count=0
    for item in "${items[@]}"; do
        if dynamodb_put_item "$table_name" "$item" "$region"; then
            success_count=$((success_count + 1))
            print_success "Inserted item $success_count/3"
        else
            print_error "Failed to insert item"
        fi
    done

    if [ $success_count -eq 3 ]; then
        print_success "All sample data inserted successfully"
        return 0
    else
        print_warning "Only $success_count/3 items were inserted"
        return 1
    fi
}

verify_data() {
    local table_name="$1"
    local region="$2"

    print_section "Verifying inserted data..."

    local scan_result=$(aws dynamodb scan \
        --table-name "$table_name" \
        --region "$region" \
        --output json 2>/dev/null)

    if [ $? -ne 0 ]; then
        print_error "Failed to scan table"
        return 1
    fi

    local count=$(json_get "$scan_result" '.Count')

    if [ -n "$count" ] && [ "$count" -gt 0 ]; then
        print_success "Found $count item(s) in the table"

        print_info "Sample data preview:"
        echo "$scan_result" | jq -r '.Items[] | "  ID: \(.id.N) | Name: \(.name.S) | Price: \(.price.N) | Category: \(.category.S // "N/A")"' 2>/dev/null

        return 0
    else
        print_error "No items found in the table"
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    local exit_code=0

    # Validate arguments
    if [ -z "$TABLE_NAME" ]; then
        print_error "Table name is required"
        echo ""
        echo "Usage: $0 [TABLE_NAME] [ENVIRONMENT]"
        echo "Example: $0 my-table-dev dev"
        exit 1
    fi

    print_header "Setting Up DynamoDB Table: $TABLE_NAME"

    show_env_info "$ENVIRONMENT" "$REGION"
    print_info "Table Name: $TABLE_NAME"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        print_warning "Some features may be limited without jq"
    fi

    # Step 1: Check if table exists
    if dynamodb_table_exists "$TABLE_NAME" "$REGION" > /dev/null; then
        print_success "Table '$TABLE_NAME' already exists"

        # Check if data exists, insert if not
        print_info "Checking if table has data..."
        if has_data "$TABLE_NAME" "$REGION"; then
            print_success "Table already contains data. Skipping data insertion."
        else
            print_info "Table exists but has no data. Inserting sample data..."
            if ! insert_sample_data "$TABLE_NAME" "$REGION"; then
                print_warning "Some data insertion failed"
                exit_code=1
            fi
            if ! verify_data "$TABLE_NAME" "$REGION"; then
                exit_code=1
            fi
        fi
    else
        print_info "Table '$TABLE_NAME' does not exist. Creating..."

        # Step 2: Create table
        print_info "Attribute Name: $ATTRIBUTE_NAME ($ATTRIBUTE_TYPE)"
        print_info "Read Capacity: $READ_CAPACITY_UNITS"
        print_info "Write Capacity: $WRITE_CAPACITY_UNITS"

        if ! dynamodb_create_table "$TABLE_NAME" "$ATTRIBUTE_NAME" "$ATTRIBUTE_TYPE" "$REGION" "$READ_CAPACITY_UNITS" "$WRITE_CAPACITY_UNITS"; then
            print_error "Failed to create table"
            return 1
        fi
        print_success "Table creation initiated"

        # Wait for table to be active
        dynamodb_wait_active "$TABLE_NAME" "$REGION"

        # Step 3: Insert sample data
        print_info "Inserting sample data into newly created table..."
        if ! insert_sample_data "$TABLE_NAME" "$REGION"; then
            print_warning "Some data insertion failed"
            exit_code=1
        fi
        if ! verify_data "$TABLE_NAME" "$REGION"; then
            exit_code=1
        fi
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
    print_info "  Scan table:   aws dynamodb scan --table-name $TABLE_NAME --region $REGION"
    print_info "  Get item:     aws dynamodb get-item --table-name $TABLE_NAME --key '{\"id\": {\"N\": \"1\"}}' --region $REGION"
    print_info "  Delete table: aws dynamodb delete-table --table-name $TABLE_NAME --region $REGION"

    return $exit_code
}

main "$@"
exit $?
