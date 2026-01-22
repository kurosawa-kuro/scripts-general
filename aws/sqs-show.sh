#!/bin/bash
# =============================================================================
# Show AWS SQS Queue Details
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

QUEUE_NAME="${1:-}"
REGION="$(aws_get_region)"

print_usage() {
    echo "Show AWS SQS Queue Details"
    echo ""
    echo "Usage:"
    echo "  $0 QUEUE_NAME       # Show queue details"
    echo "  $0 --list           # List all queues"
    echo "  $0 --help           # Show this help"
}

list_queues() {
    print_header "SQS Queues"
    print_info "Region: $REGION"
    echo ""

    local queues=$(sqs_list_queues "$REGION")
    local urls=$(echo "$queues" | jq -r '.QueueUrls[]?' 2>/dev/null)

    if [ -z "$urls" ]; then
        print_info "No queues found"
        return 0
    fi

    echo "$urls" | while read -r url; do
        local name=$(basename "$url")
        local attrs=$(sqs_get_attributes "$url" "$REGION")
        local msgs=$(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessages // "0"')
        local inflight=$(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessagesNotVisible // "0"')
        printf "  %-35s Messages: %s (in-flight: %s)\n" "$name" "$msgs" "$inflight"
    done
}

show_queue() {
    local name="$1"

    if ! sqs_queue_exists "$name" "$REGION"; then
        print_error "Queue '$name' not found"
        return 1
    fi

    print_header "SQS Queue: $name"

    local url=$(sqs_get_queue_url "$name" "$REGION")
    local attrs=$(sqs_get_attributes "$url" "$REGION")

    print_section "Queue Details"
    echo "  Name: $name"
    echo "  URL:  $url"
    echo "  ARN:  $(echo "$attrs" | jq -r '.Attributes.QueueArn')"

    print_section "Messages"
    echo "  Available:  $(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessages')"
    echo "  In-flight:  $(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessagesNotVisible')"
    echo "  Delayed:    $(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessagesDelayed')"

    print_section "Configuration"
    echo "  Visibility Timeout: $(echo "$attrs" | jq -r '.Attributes.VisibilityTimeout')s"
    echo "  Message Retention:  $(echo "$attrs" | jq -r '.Attributes.MessageRetentionPeriod')s"
    echo "  Max Message Size:   $(echo "$attrs" | jq -r '.Attributes.MaximumMessageSize') bytes"
    echo "  Delay Seconds:      $(echo "$attrs" | jq -r '.Attributes.DelaySeconds')s"

    local fifo=$(echo "$attrs" | jq -r '.Attributes.FifoQueue // "false"')
    if [ "$fifo" = "true" ]; then
        print_section "FIFO Settings"
        echo "  Content Deduplication: $(echo "$attrs" | jq -r '.Attributes.ContentBasedDeduplication')"
        echo "  Deduplication Scope:   $(echo "$attrs" | jq -r '.Attributes.DeduplicationScope // "queue"')"
    fi

    echo ""
    print_info "Commands:"
    echo "  Send:    aws sqs send-message --queue-url '$url' --message-body 'test'"
    echo "  Receive: aws sqs receive-message --queue-url '$url'"
    echo "  Purge:   aws sqs purge-queue --queue-url '$url'"
}

case "${1:-}" in
    --help|-h) print_usage; exit 0 ;;
    --list|-l) list_queues; exit 0 ;;
esac

if ! require_aws_cli; then exit 1; fi

if [ -z "$QUEUE_NAME" ]; then
    list_queues
else
    show_queue "$QUEUE_NAME"
fi
