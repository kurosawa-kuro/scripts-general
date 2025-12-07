#!/bin/bash
# =============================================================================
# AWS Cost Explorer
# =============================================================================
# Purpose: Display AWS cost information for current month and trends
# Usage:
#   ./aws-cost.sh                    # Show current month costs
#   ./aws-cost.sh --daily            # Show daily breakdown
#   ./aws-cost.sh --services         # Show cost by service
#   ./aws-cost.sh --forecast         # Show cost forecast
#   ./aws-cost.sh --help
#
# Note: AWS Cost Explorer API must be enabled in your account
#       (may take 24 hours to activate)
#
# Environment Variables:
#   AWS_REGION   - AWS region (default: ap-northeast-1)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

# =============================================================================
# Configuration
# =============================================================================

REGION="$(aws_get_region 2>/dev/null || echo 'ap-northeast-1')"

# Date calculations
CURRENT_MONTH_START=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
CURRENT_DATE=$(date +%Y-%m-%d)
NEXT_MONTH_START=$(date -d "$(date +%Y-%m-01) +1 month" +%Y-%m-%d)
LAST_MONTH_START=$(date -d "$(date +%Y-%m-01) -1 month" +%Y-%m-%d)
LAST_MONTH_END=$(date -d "$(date +%Y-%m-01) -1 day" +%Y-%m-%d)

# =============================================================================
# Functions
# =============================================================================

print_usage() {
    echo "AWS Cost Explorer"
    echo ""
    echo "Usage:"
    echo "  $0                    # Show current month costs"
    echo "  $0 --daily            # Show daily breakdown (last 14 days)"
    echo "  $0 --services         # Show cost by service"
    echo "  $0 --forecast         # Show cost forecast"
    echo "  $0 --compare          # Compare with last month"
    echo "  $0 --help             # Show this help"
    echo ""
    echo "Note: Cost Explorer API must be enabled in your AWS account"
}

get_month_to_date_cost() {
    print_section "Month-to-Date Cost"

    local result=$(aws ce get-cost-and-usage \
        --time-period "Start=$CURRENT_MONTH_START,End=$CURRENT_DATE" \
        --granularity MONTHLY \
        --metrics "BlendedCost" "UnblendedCost" \
        --output json 2>/dev/null)

    if [ -z "$result" ]; then
        print_error "Failed to fetch cost data"
        print_info "Ensure Cost Explorer API is enabled in your account"
        return 1
    fi

    local blended=$(echo "$result" | jq -r '.ResultsByTime[0].Total.BlendedCost.Amount // "0"')
    local unblended=$(echo "$result" | jq -r '.ResultsByTime[0].Total.UnblendedCost.Amount // "0"')
    local currency=$(echo "$result" | jq -r '.ResultsByTime[0].Total.BlendedCost.Unit // "USD"')

    printf "  Period:         %s to %s\n" "$CURRENT_MONTH_START" "$CURRENT_DATE"
    printf "  Blended Cost:   %.2f %s\n" "$blended" "$currency"
    printf "  Unblended Cost: %.2f %s\n" "$unblended" "$currency"
}

get_daily_costs() {
    print_section "Daily Cost Breakdown (Last 14 Days)"

    local start_date=$(date -d "14 days ago" +%Y-%m-%d)

    local result=$(aws ce get-cost-and-usage \
        --time-period "Start=$start_date,End=$CURRENT_DATE" \
        --granularity DAILY \
        --metrics "BlendedCost" \
        --output json 2>/dev/null)

    if [ -z "$result" ]; then
        print_error "Failed to fetch daily cost data"
        return 1
    fi

    printf "  %-12s %12s\n" "DATE" "COST (USD)"
    printf "  %-12s %12s\n" "----" "----------"

    echo "$result" | jq -r '.ResultsByTime[] | "  \(.TimePeriod.Start)  \(.Total.BlendedCost.Amount | tonumber | . * 100 | floor / 100)"'

    local total=$(echo "$result" | jq -r '[.ResultsByTime[].Total.BlendedCost.Amount | tonumber] | add')
    printf "  %-12s %12.2f\n" "TOTAL" "$total"
}

get_cost_by_service() {
    print_section "Cost by Service (Current Month)"

    local result=$(aws ce get-cost-and-usage \
        --time-period "Start=$CURRENT_MONTH_START,End=$CURRENT_DATE" \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --group-by Type=DIMENSION,Key=SERVICE \
        --output json 2>/dev/null)

    if [ -z "$result" ]; then
        print_error "Failed to fetch cost by service"
        return 1
    fi

    printf "  %-45s %12s\n" "SERVICE" "COST (USD)"
    printf "  %-45s %12s\n" "-------" "----------"

    echo "$result" | jq -r '
        .ResultsByTime[0].Groups
        | sort_by(.Metrics.BlendedCost.Amount | tonumber)
        | reverse
        | .[0:15]
        | .[]
        | "  \(.Keys[0] | .[0:45] | . + (" " * (45 - length))) \(.Metrics.BlendedCost.Amount | tonumber | . * 100 | floor / 100 | tostring | " " * (12 - length) + .)"'

    local total=$(echo "$result" | jq -r '[.ResultsByTime[0].Groups[].Metrics.BlendedCost.Amount | tonumber] | add')
    echo ""
    printf "  %-45s %12.2f\n" "TOTAL" "$total"
}

get_cost_forecast() {
    print_section "Cost Forecast"

    local result=$(aws ce get-cost-forecast \
        --time-period "Start=$CURRENT_DATE,End=$NEXT_MONTH_START" \
        --granularity MONTHLY \
        --metric "BLENDED_COST" \
        --output json 2>/dev/null)

    if [ -z "$result" ]; then
        print_warning "Cost forecast not available"
        print_info "Forecasts require sufficient historical data"
        return 0
    fi

    local forecast=$(echo "$result" | jq -r '.Total.Amount // "N/A"')
    local currency=$(echo "$result" | jq -r '.Total.Unit // "USD"')

    printf "  Forecast Period: %s to %s\n" "$CURRENT_DATE" "$NEXT_MONTH_START"
    printf "  Forecasted Cost: %.2f %s\n" "$forecast" "$currency"

    # Get prediction intervals if available
    local lower=$(echo "$result" | jq -r '.ForecastResultsByTime[0].PredictionIntervalLowerBound // empty')
    local upper=$(echo "$result" | jq -r '.ForecastResultsByTime[0].PredictionIntervalUpperBound // empty')

    if [ -n "$lower" ] && [ -n "$upper" ]; then
        printf "  Prediction Range: %.2f - %.2f %s\n" "$lower" "$upper" "$currency"
    fi
}

compare_with_last_month() {
    print_section "Month Comparison"

    # Current month to date
    local current=$(aws ce get-cost-and-usage \
        --time-period "Start=$CURRENT_MONTH_START,End=$CURRENT_DATE" \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --output json 2>/dev/null)

    # Same period last month
    local days_elapsed=$(( ($(date +%s) - $(date -d "$CURRENT_MONTH_START" +%s)) / 86400 ))
    local last_month_same_day=$(date -d "$LAST_MONTH_START +$days_elapsed days" +%Y-%m-%d)

    local last_month=$(aws ce get-cost-and-usage \
        --time-period "Start=$LAST_MONTH_START,End=$last_month_same_day" \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --output json 2>/dev/null)

    # Full last month
    local last_month_full=$(aws ce get-cost-and-usage \
        --time-period "Start=$LAST_MONTH_START,End=$LAST_MONTH_END" \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --output json 2>/dev/null)

    local current_cost=$(echo "$current" | jq -r '.ResultsByTime[0].Total.BlendedCost.Amount // "0"' | awk '{printf "%.2f", $1}')
    local last_same_cost=$(echo "$last_month" | jq -r '.ResultsByTime[0].Total.BlendedCost.Amount // "0"' | awk '{printf "%.2f", $1}')
    local last_full_cost=$(echo "$last_month_full" | jq -r '.ResultsByTime[0].Total.BlendedCost.Amount // "0"' | awk '{printf "%.2f", $1}')

    printf "  Current Month (to date):     \$%.2f\n" "$current_cost"
    printf "  Last Month (same period):    \$%.2f\n" "$last_same_cost"
    printf "  Last Month (full):           \$%.2f\n" "$last_full_cost"

    # Calculate difference
    if [ "$(echo "$last_same_cost > 0" | bc -l)" = "1" ]; then
        local diff=$(echo "scale=2; (($current_cost - $last_same_cost) / $last_same_cost) * 100" | bc -l)
        if [ "$(echo "$diff >= 0" | bc -l)" = "1" ]; then
            printf "  Change from last month:      ${RED}+%.1f%%${NC}\n" "$diff"
        else
            printf "  Change from last month:      ${GREEN}%.1f%%${NC}\n" "$diff"
        fi
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
        --daily|-d)
            print_header "AWS Daily Cost Breakdown"
            get_daily_costs
            exit 0
            ;;
        --services|-s)
            print_header "AWS Cost by Service"
            get_cost_by_service
            exit 0
            ;;
        --forecast|-f)
            print_header "AWS Cost Forecast"
            get_cost_forecast
            exit 0
            ;;
        --compare|-c)
            print_header "AWS Cost Comparison"
            compare_with_last_month
            exit 0
            ;;
    esac

    print_header "AWS Cost Summary"

    # Check prerequisites
    if ! command -v aws &>/dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        print_error "jq is required"
        exit 1
    fi

    # Show account info
    local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "N/A")
    print_info "AWS Account: $account_id"
    print_info "Date: $CURRENT_DATE"
    echo ""

    # Get all cost information
    get_month_to_date_cost
    echo ""
    get_cost_by_service
    echo ""
    get_cost_forecast
    echo ""

    print_info "For more details:"
    echo "  Daily breakdown:  $0 --daily"
    echo "  Compare months:   $0 --compare"
    echo "  AWS Console:      https://console.aws.amazon.com/cost-management/"

    return 0
}

main "$@"
exit $?
