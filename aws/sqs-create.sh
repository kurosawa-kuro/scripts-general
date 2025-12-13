#!/bin/bash
# =============================================================================
# Create AWS SQS Queue
# =============================================================================
# Purpose: Create SQS queues (standard or FIFO)
# Usage:
#   ./sqs-create.sh QUEUE_NAME
#   ./sqs-create.sh QUEUE_NAME --fifo
#   ./sqs-create.sh --help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

QUEUE_NAME="${1:-}"
REGION="$(aws_get_region)"
FIFO_MODE=false
VISIBILITY_TIMEOUT=30
MESSAGE_RETENTION=345600

print_usage() {
    echo "Create AWS SQS Queue"
    echo ""
    echo "Usage:"
    echo "  $0 QUEUE_NAME                 # Create standard queue"
    echo "  $0 QUEUE_NAME --fifo          # Create FIFO queue"
    echo "  $0 --list                     # List all queues"
    echo "  $0 --help                     # Show this help"
    echo ""
    echo "Options:"
    echo "  --fifo                FIFO queue (exactly-once processing)"
    echo "  --visibility SEC      Visibility timeout (default: 30)"
    echo "  --retention SEC       Message retention (default: 345600 = 4 days)"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fifo|-f) FIFO_MODE=true; shift ;;
            --visibility) VISIBILITY_TIMEOUT="$2"; shift 2 ;;
            --retention) MESSAGE_RETENTION="$2"; shift 2 ;;
            --list|-l) list_queues; exit 0 ;;
            --help|-h) print_usage; exit 0 ;;
            *) [ -z "$QUEUE_NAME" ] && QUEUE_NAME="$1"; shift ;;
        esac
    done
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

    printf "  %-40s %s\n" "QUEUE NAME" "URL"
    printf "  %-40s %s\n" "----------" "---"

    echo "$urls" | while read -r url; do
        local name=$(basename "$url")
        printf "  %-40s %s\n" "$name" "$url"
    done
}

main() {
    parse_args "$@"

    if [ -z "$QUEUE_NAME" ]; then
        print_error "Queue name required"
        print_usage
        exit 1
    fi

    print_header "Create SQS Queue: $QUEUE_NAME"
    show_env_info "sqs" "$REGION"

    if ! require_aws_cli; then return 1; fi

    # Check if exists
    if sqs_queue_exists "$QUEUE_NAME" "$REGION"; then
        print_warning "Queue '$QUEUE_NAME' already exists"
        local url=$(sqs_get_queue_url "$QUEUE_NAME" "$REGION")
        print_info "URL: $url"
        return 0
    fi

    # Create queue
    print_section "Creating Queue"
    print_info "Type: $([ "$FIFO_MODE" = true ] && echo "FIFO" || echo "Standard")"

    local result
    if [ "$FIFO_MODE" = true ]; then
        result=$(sqs_create_fifo_queue "$QUEUE_NAME" "$REGION")
    else
        result=$(sqs_create_queue "$QUEUE_NAME" "$REGION" "$VISIBILITY_TIMEOUT" "$MESSAGE_RETENTION")
    fi

    if [ -z "$result" ]; then
        print_error "Failed to create queue"
        return 1
    fi

    local url=$(echo "$result" | jq -r '.QueueUrl')
    print_success "Queue created"

    echo ""
    print_section "Queue Information"
    echo "  Name: $QUEUE_NAME"
    echo "  URL:  $url"

    echo ""
    print_info "Commands:"
    echo "  Show:    make sqs-show NAME=$QUEUE_NAME"
    echo "  Send:    make sqs-send NAME=$QUEUE_NAME MESSAGE='hello'"
    echo "  Receive: make sqs-receive NAME=$QUEUE_NAME"
}

main "$@"
exit $?
