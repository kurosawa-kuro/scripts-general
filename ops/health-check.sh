#!/bin/bash
# =============================================================================
# Health Check Script
# =============================================================================
# Purpose: Check health of endpoints, services, and infrastructure
# Usage:
#   ./health-check.sh URL [URL...]
#   ./health-check.sh --file endpoints.txt
#   ./health-check.sh --k8s
#   ./health-check.sh --help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/core.sh"

TIMEOUT=10
URLS=()
CHECK_K8S=false
CHECK_AWS=false
FROM_FILE=""

print_usage() {
    echo "Health Check Script"
    echo ""
    echo "Usage:"
    echo "  $0 URL [URL...]              # Check HTTP endpoints"
    echo "  $0 --file FILE               # Check endpoints from file"
    echo "  $0 --k8s                     # Check Kubernetes cluster"
    echo "  $0 --aws                     # Check AWS services"
    echo "  $0 --all                     # Run all checks"
    echo "  $0 --help                    # Show this help"
    echo ""
    echo "Options:"
    echo "  --timeout SEC   Request timeout (default: 10)"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --timeout|-t) TIMEOUT="$2"; shift 2 ;;
            --file|-f) FROM_FILE="$2"; shift 2 ;;
            --k8s) CHECK_K8S=true; shift ;;
            --aws) CHECK_AWS=true; shift ;;
            --all) CHECK_K8S=true; CHECK_AWS=true; shift ;;
            --help|-h) print_usage; exit 0 ;;
            *) URLS+=("$1"); shift ;;
        esac
    done
}

check_url() {
    local url="$1"
    local start=$(date +%s%3N)

    local status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$TIMEOUT" "$url" 2>/dev/null || echo "000")

    local end=$(date +%s%3N)
    local duration=$((end - start))

    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
        printf "  ${GREEN}[OK]${NC}  %-50s %s (%dms)\n" "$url" "$status" "$duration"
        return 0
    elif [[ "$status" =~ ^3[0-9][0-9]$ ]]; then
        printf "  ${YELLOW}[REDIRECT]${NC} %-50s %s (%dms)\n" "$url" "$status" "$duration"
        return 0
    else
        printf "  ${RED}[FAIL]${NC} %-50s %s (%dms)\n" "$url" "$status" "$duration"
        return 1
    fi
}

check_http_endpoints() {
    print_section "HTTP Endpoints"

    local failed=0

    for url in "${URLS[@]}"; do
        if ! check_url "$url"; then
            ((failed++))
        fi
    done

    echo ""
    local total=${#URLS[@]}
    local passed=$((total - failed))

    if [ $failed -eq 0 ]; then
        print_success "All $total endpoints healthy"
    else
        print_warning "$passed/$total endpoints healthy, $failed failed"
    fi

    return $failed
}

check_kubernetes() {
    print_section "Kubernetes Cluster"

    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        print_error "kubectl not installed"
        return 1
    fi

    # Check cluster connection
    if kubectl cluster-info &>/dev/null; then
        local context=$(kubectl config current-context 2>/dev/null)
        print_success "Connected to: $context"
    else
        print_error "Cannot connect to cluster"
        return 1
    fi

    # Check nodes
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null)
    local total_nodes=$(echo "$nodes" | wc -l)
    local ready_nodes=$(echo "$nodes" | grep -c " Ready " || echo "0")

    if [ "$ready_nodes" -eq "$total_nodes" ]; then
        print_success "Nodes: $ready_nodes/$total_nodes ready"
    else
        print_warning "Nodes: $ready_nodes/$total_nodes ready"
    fi

    # Check system pods
    local system_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null)
    local total_system=$(echo "$system_pods" | wc -l)
    local running_system=$(echo "$system_pods" | grep -c "Running" || echo "0")

    if [ "$running_system" -eq "$total_system" ]; then
        print_success "System pods: $running_system/$total_system running"
    else
        print_warning "System pods: $running_system/$total_system running"
    fi

    return 0
}

check_aws_services() {
    print_section "AWS Services"

    # Check AWS CLI
    if ! command -v aws &>/dev/null; then
        print_error "AWS CLI not installed"
        return 1
    fi

    # Check credentials
    if aws sts get-caller-identity &>/dev/null; then
        local account=$(aws sts get-caller-identity --query Account --output text)
        print_success "AWS Account: $account"
    else
        print_error "AWS credentials invalid"
        return 1
    fi

    # Check common services
    local region="${AWS_REGION:-ap-northeast-1}"

    # EC2
    if aws ec2 describe-instances --region "$region" --max-items 1 &>/dev/null; then
        print_success "EC2: accessible"
    else
        print_warning "EC2: not accessible"
    fi

    # S3
    if aws s3 ls --region "$region" &>/dev/null; then
        print_success "S3: accessible"
    else
        print_warning "S3: not accessible"
    fi

    return 0
}

main() {
    parse_args "$@"

    print_header "Health Check"
    print_info "Timestamp: $(date -Iseconds)"

    local exit_code=0

    # Load URLs from file
    if [ -n "$FROM_FILE" ]; then
        if [ -f "$FROM_FILE" ]; then
            while IFS= read -r line; do
                [[ -n "$line" && ! "$line" =~ ^# ]] && URLS+=("$line")
            done < "$FROM_FILE"
        else
            print_error "File not found: $FROM_FILE"
            exit 1
        fi
    fi

    # Check HTTP endpoints
    if [ ${#URLS[@]} -gt 0 ]; then
        if ! check_http_endpoints; then
            exit_code=1
        fi
        echo ""
    fi

    # Check Kubernetes
    if [ "$CHECK_K8S" = true ]; then
        if ! check_kubernetes; then
            exit_code=1
        fi
        echo ""
    fi

    # Check AWS
    if [ "$CHECK_AWS" = true ]; then
        if ! check_aws_services; then
            exit_code=1
        fi
        echo ""
    fi

    # Summary
    if [ $exit_code -eq 0 ]; then
        print_success "All health checks passed"
    else
        print_error "Some health checks failed"
    fi

    return $exit_code
}

main "$@"
exit $?
