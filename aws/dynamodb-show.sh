#!/bin/bash
# =============================================================================
# Check DynamoDB Table
# =============================================================================
#
# This script:
# 1. Shows table information
# 2. Lists items with sample data preview
# 3. Shows table statistics
#
# Usage:
#   ./dynamodb-show.sh [TABLE_NAME]
#   ./dynamodb-show.sh --list
#
# Examples:
#   ./dynamodb-show.sh my-table
#   ./dynamodb-show.sh --list
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

TABLE_NAME="${1}"
REGION="$(aws_get_region)"

# =============================================================================
# Functions
# =============================================================================

list_tables() {
    print_section "DynamoDB Tables"

    local tables=$(aws dynamodb list-tables --region "$REGION" --output json 2>/dev/null)

    if [ -z "$tables" ]; then
        print_info "No tables found"
        return 0
    fi

    local count=$(echo "$tables" | jq -r '.TableNames | length')

    if [ "$count" -eq 0 ]; then
        print_info "No tables found"
        return 0
    fi

    print_success "Found $count table(s)"
    echo ""

    echo "$tables" | jq -r '.TableNames[]' | while read -r table; do
        local status=$(aws dynamodb describe-table --table-name "$table" --region "$REGION" \
            --query 'Table.TableStatus' --output text 2>/dev/null)
        local item_count=$(aws dynamodb describe-table --table-name "$table" --region "$REGION" \
            --query 'Table.ItemCount' --output text 2>/dev/null)
        printf "  %-40s %-10s %s items\n" "$table" "$status" "$item_count"
    done
}

show_table_info() {
    local table_name="$1"

    print_section "Table Information"

    local table_info=$(dynamodb_table_exists "$table_name" "$REGION")

    if [ -z "$table_info" ] || echo "$table_info" | grep -q "ResourceNotFoundException"; then
        print_error "Table '$table_name' not found"
        return 1
    fi

    local table_arn=$(json_get "$table_info" '.Table.TableArn')
    local table_status=$(json_get "$table_info" '.Table.TableStatus')
    local created_at=$(json_get "$table_info" '.Table.CreationDateTime')
    local item_count=$(json_get "$table_info" '.Table.ItemCount')
    local table_size=$(json_get "$table_info" '.Table.TableSizeBytes')
    local pk_name=$(json_get "$table_info" '.Table.KeySchema[0].AttributeName')
    local pk_type=$(echo "$table_info" | jq -r '.Table.AttributeDefinitions[] | select(.AttributeName == "'"$pk_name"'") | .AttributeType')
    local rcu=$(json_get "$table_info" '.Table.ProvisionedThroughput.ReadCapacityUnits')
    local wcu=$(json_get "$table_info" '.Table.ProvisionedThroughput.WriteCapacityUnits')
    local billing_mode=$(json_get "$table_info" '.Table.BillingModeSummary.BillingMode' 'PROVISIONED')

    # Convert size to human readable
    local size_kb=$((table_size / 1024))

    echo "  Name:           $table_name"
    echo "  ARN:            $table_arn"
    echo "  Status:         $table_status"
    echo "  Created:        $created_at"
    echo "  Item Count:     $item_count"
    echo "  Size:           ${size_kb} KB"
    echo "  Primary Key:    $pk_name ($pk_type)"
    echo "  Billing Mode:   $billing_mode"
    if [ "$billing_mode" = "PROVISIONED" ]; then
        echo "  Read Capacity:  $rcu"
        echo "  Write Capacity: $wcu"
    fi
}

show_items() {
    local table_name="$1"
    local limit="${2:-10}"

    print_section "Items (up to $limit)"

    local scan_result=$(aws dynamodb scan \
        --table-name "$table_name" \
        --region "$REGION" \
        --limit "$limit" \
        --output json 2>/dev/null)

    if [ -z "$scan_result" ]; then
        print_info "Failed to scan table"
        return 0
    fi

    local count=$(json_get "$scan_result" '.Count')
    local scanned_count=$(json_get "$scan_result" '.ScannedCount')

    if [ "$count" -eq 0 ]; then
        print_info "No items found"
        return 0
    fi

    print_success "Showing $count item(s)"
    echo ""

    # Try to display items in a readable format
    echo "$scan_result" | jq -r '.Items[] | to_entries | map("\(.key): \(.value | to_entries[0].value)") | "  " + join(" | ")' 2>/dev/null || \
    echo "$scan_result" | jq -c '.Items[]' 2>/dev/null
}

show_gsi_info() {
    local table_name="$1"

    local table_info=$(dynamodb_table_exists "$table_name" "$REGION")
    local gsi_count=$(echo "$table_info" | jq -r '.Table.GlobalSecondaryIndexes | length // 0')

    if [ "$gsi_count" -gt 0 ]; then
        print_section "Global Secondary Indexes ($gsi_count)"
        echo "$table_info" | jq -r '.Table.GlobalSecondaryIndexes[] | "  \(.IndexName) - \(.KeySchema | map(.AttributeName + ":" + .KeyType) | join(", ")) [\(.IndexStatus)]"'
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Handle --list flag
    if [ "$TABLE_NAME" = "--list" ] || [ "$TABLE_NAME" = "-l" ]; then
        print_header "DynamoDB Tables"

        if ! require_aws_cli; then
            return 1
        fi

        list_tables
        return 0
    fi

    # Validate arguments
    if [ -z "$TABLE_NAME" ]; then
        print_error "Table name is required"
        echo ""
        echo "Usage: $0 [TABLE_NAME]"
        echo "       $0 --list"
        echo ""
        echo "Example: $0 my-table"
        exit 1
    fi

    print_header "DynamoDB Table: $TABLE_NAME"

    # Check prerequisites
    if ! require_aws_cli; then
        return 1
    fi

    if ! require_jq; then
        print_error "jq is required for this script"
        return 1
    fi

    # Show table info
    if ! show_table_info "$TABLE_NAME"; then
        return 1
    fi

    # Show GSI info
    show_gsi_info "$TABLE_NAME"

    # Show items
    show_items "$TABLE_NAME"

    # Summary
    echo ""
    print_info "Useful commands:"
    print_info "  Scan all:    aws dynamodb scan --table-name $TABLE_NAME --region $REGION"
    print_info "  Get item:    aws dynamodb get-item --table-name $TABLE_NAME --key '{\"id\": {\"N\": \"1\"}}' --region $REGION"
    print_info "  Delete:      aws dynamodb delete-table --table-name $TABLE_NAME --region $REGION"

    return 0
}

main "$@"
exit $?
