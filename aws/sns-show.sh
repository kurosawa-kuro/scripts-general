#!/bin/bash
# =============================================================================
# Show AWS SNS Topic Details
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

TOPIC_NAME="${1:-}"
REGION="$(aws_get_region)"

print_usage() {
    echo "Show AWS SNS Topic Details"
    echo ""
    echo "Usage:"
    echo "  $0 TOPIC_NAME       # Show topic details"
    echo "  $0 --list           # List all topics"
    echo "  $0 --help           # Show this help"
}

list_topics() {
    print_header "SNS Topics"
    print_info "Region: $REGION"
    echo ""

    local topics=$(sns_list_topics "$REGION")
    local arns=$(echo "$topics" | jq -r '.Topics[].TopicArn' 2>/dev/null)

    if [ -z "$arns" ]; then
        print_info "No topics found"
        return 0
    fi

    echo "$arns" | while read -r arn; do
        local name=$(echo "$arn" | awk -F: '{print $NF}')
        local subs=$(sns_list_subscriptions "$arn" "$REGION" | jq -r '.Subscriptions | length')
        printf "  %-35s Subscriptions: %s\n" "$name" "$subs"
    done
}

show_topic() {
    local name="$1"
    local arn=$(sns_get_topic_arn "$name" "$REGION")

    print_header "SNS Topic: $name"

    local attrs=$(sns_get_topic_attributes "$arn" "$REGION")

    if [ -z "$attrs" ]; then
        print_error "Topic '$name' not found or access denied"
        return 1
    fi

    print_section "Topic Details"
    echo "  Name:  $name"
    echo "  ARN:   $arn"
    echo "  Owner: $(echo "$attrs" | jq -r '.Attributes.Owner')"

    print_section "Subscriptions"
    local subs=$(sns_list_subscriptions "$arn" "$REGION")
    local sub_list=$(echo "$subs" | jq -r '.Subscriptions[]?' 2>/dev/null)

    if [ -z "$sub_list" ]; then
        print_info "No subscriptions"
    else
        echo "$subs" | jq -r '.Subscriptions[] | "  \(.Protocol): \(.Endpoint) [\(.SubscriptionArn | split(":") | .[-1])]"' 2>/dev/null
    fi

    print_section "Delivery Status"
    local pending=$(echo "$attrs" | jq -r '.Attributes.SubscriptionsPending // "0"')
    local confirmed=$(echo "$attrs" | jq -r '.Attributes.SubscriptionsConfirmed // "0"')
    local deleted=$(echo "$attrs" | jq -r '.Attributes.SubscriptionsDeleted // "0"')
    echo "  Confirmed: $confirmed"
    echo "  Pending:   $pending"
    echo "  Deleted:   $deleted"

    echo ""
    print_info "Commands:"
    echo "  Publish:   aws sns publish --topic-arn '$arn' --message 'test'"
    echo "  Subscribe: aws sns subscribe --topic-arn '$arn' --protocol email --notification-endpoint user@example.com"
}

case "${1:-}" in
    --help|-h) print_usage; exit 0 ;;
    --list|-l) list_topics; exit 0 ;;
esac

if ! require_aws_cli; then exit 1; fi

if [ -z "$TOPIC_NAME" ]; then
    list_topics
else
    show_topic "$TOPIC_NAME"
fi
