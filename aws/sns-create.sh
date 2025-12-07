#!/bin/bash
# =============================================================================
# Create AWS SNS Topic
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

TOPIC_NAME="${1:-}"
REGION="$(aws_get_region)"

print_usage() {
    echo "Create AWS SNS Topic"
    echo ""
    echo "Usage:"
    echo "  $0 TOPIC_NAME                    # Create topic"
    echo "  $0 TOPIC_NAME --subscribe EMAIL  # Create and subscribe"
    echo "  $0 --list                        # List all topics"
    echo "  $0 --help                        # Show this help"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --subscribe) SUBSCRIBE_EMAIL="$2"; shift 2 ;;
            --list|-l) list_topics; exit 0 ;;
            --help|-h) print_usage; exit 0 ;;
            *) [ -z "$TOPIC_NAME" ] && TOPIC_NAME="$1"; shift ;;
        esac
    done
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

    printf "  %-40s %s\n" "TOPIC NAME" "ARN"
    printf "  %-40s %s\n" "----------" "---"

    echo "$arns" | while read -r arn; do
        local name=$(echo "$arn" | awk -F: '{print $NF}')
        printf "  %-40s %s\n" "$name" "$arn"
    done
}

main() {
    parse_args "$@"

    if [ -z "$TOPIC_NAME" ]; then
        print_error "Topic name required"
        print_usage
        exit 1
    fi

    print_header "Create SNS Topic: $TOPIC_NAME"
    show_env_info "sns" "$REGION"

    if ! require_aws_cli; then return 1; fi

    # Create topic
    print_section "Creating Topic"

    local result=$(sns_create_topic "$TOPIC_NAME" "$REGION")

    if [ -z "$result" ]; then
        print_error "Failed to create topic"
        return 1
    fi

    local arn=$(echo "$result" | jq -r '.TopicArn')
    print_success "Topic created"

    echo ""
    print_section "Topic Information"
    echo "  Name: $TOPIC_NAME"
    echo "  ARN:  $arn"

    # Subscribe if email provided
    if [ -n "$SUBSCRIBE_EMAIL" ]; then
        print_section "Adding Subscription"
        sns_subscribe "$arn" "email" "$SUBSCRIBE_EMAIL" "$REGION" > /dev/null
        print_success "Subscription pending confirmation"
        print_info "Check $SUBSCRIBE_EMAIL for confirmation"
    fi

    echo ""
    print_info "Commands:"
    echo "  Show:      make sns-show NAME=$TOPIC_NAME"
    echo "  Publish:   make sns-publish TOPIC=$TOPIC_NAME MESSAGE='hello'"
    echo "  Subscribe: make sns-subscribe TOPIC=$TOPIC_NAME EMAIL=user@example.com"
}

main "$@"
exit $?
