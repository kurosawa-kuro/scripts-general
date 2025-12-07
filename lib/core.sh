#!/bin/bash
# =============================================================================
# Core Library for scripts-general
# =============================================================================
# Common utilities for all scripts
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/core.sh" || source "$SCRIPT_DIR/../lib/core.sh"
# =============================================================================

# Prevent multiple sourcing
[[ -n "${_CORE_SH_LOADED:-}" ]] && return 0
_CORE_SH_LOADED=1

# =============================================================================
# Colors and Formatting
# =============================================================================

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m'
export BOLD='\033[1m'

# =============================================================================
# Logging Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}--- $1 ---${NC}"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo -e "${MAGENTA}[DEBUG]${NC} $1"
}

# =============================================================================
# Requirement Checks
# =============================================================================

require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &> /dev/null; then
        print_error "$cmd is not installed"
        [[ -n "$install_hint" ]] && print_info "Install: $install_hint"
        return 1
    fi
    return 0
}

require_jq() {
    require_command "jq" "sudo apt-get install jq"
}

require_curl() {
    require_command "curl" "sudo apt-get install curl"
}

require_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        print_info "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        return 1
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid"
        print_info "Run: aws configure"
        return 1
    fi

    print_success "AWS CLI is configured"
    return 0
}

require_psql() {
    require_command "psql" "sudo apt-get install postgresql-client"
}

require_mongosh() {
    require_command "mongosh" "https://www.mongodb.com/docs/mongodb-shell/install/"
}

# =============================================================================
# AWS Utilities
# =============================================================================

aws_get_account_id() {
    aws sts get-caller-identity --query Account --output text 2>/dev/null
}

aws_get_region() {
    echo "${AWS_REGION:-ap-northeast-1}"
}

# =============================================================================
# JSON Utilities (jq required)
# =============================================================================

json_get() {
    local json="$1"
    local path="$2"
    local default="${3:-}"

    local result=$(echo "$json" | jq -r "$path // empty" 2>/dev/null)
    echo "${result:-$default}"
}

json_create() {
    # Create JSON object from key=value pairs
    # Usage: json_create key1=value1 key2=value2
    local result="{}"
    for pair in "$@"; do
        local key="${pair%%=*}"
        local value="${pair#*=}"
        result=$(echo "$result" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    done
    echo "$result"
}

# =============================================================================
# String Utilities
# =============================================================================

mask_password() {
    local str="$1"
    # Mask password in URLs (user:password@host)
    echo "$str" | sed -E 's/(:)[^:@]+(@)/\1****\2/'
}

mask_token() {
    local str="$1"
    # Mask tokens (webhooks/id/token)
    echo "$str" | sed -E 's/(webhooks\/[0-9]+\/)[^/]+/\1****/'
}

# =============================================================================
# Network Utilities
# =============================================================================

check_dns() {
    local host="$1"

    if command -v host &> /dev/null; then
        host "$host" > /dev/null 2>&1 && return 0
    elif command -v nslookup &> /dev/null; then
        nslookup "$host" > /dev/null 2>&1 && return 0
    elif command -v getent &> /dev/null; then
        getent hosts "$host" > /dev/null 2>&1 && return 0
    fi
    return 1
}

check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"

    if command -v nc &> /dev/null; then
        nc -z -w "$timeout" "$host" "$port" 2>/dev/null && return 0
    elif command -v timeout &> /dev/null; then
        timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null && return 0
    fi
    return 1
}

# =============================================================================
# Process Utilities
# =============================================================================

get_pids_on_port() {
    local port="$1"

    if command -v lsof &> /dev/null; then
        lsof -ti :"$port" 2>/dev/null
    elif command -v ss &> /dev/null; then
        ss -lptn "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+'
    elif command -v netstat &> /dev/null; then
        netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1
    fi
}

get_pids_by_pattern() {
    local pattern="$1"
    pgrep -f "$pattern" 2>/dev/null
}

kill_pids() {
    local pids="$1"
    local signal="${2:-9}"

    for pid in $pids; do
        kill -"$signal" "$pid" 2>/dev/null && print_success "Killed PID $pid" || print_error "Failed to kill PID $pid"
    done
}

# =============================================================================
# Environment Info
# =============================================================================

show_env_info() {
    local env="${1:-dev}"
    local region="${2:-$(aws_get_region)}"

    print_section "Environment Information"
    print_info "Environment: $env"
    print_info "Region: $region"

    if command -v aws &> /dev/null; then
        local account=$(aws_get_account_id)
        [[ -n "$account" ]] && print_info "AWS Account: $account"
    fi
}

# =============================================================================
# Confirm Prompt
# =============================================================================

confirm() {
    local message="${1:-Are you sure?}"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        read -p "$message (Y/n): " -r
        [[ -z "$REPLY" || "$REPLY" =~ ^[Yy]$ ]]
    else
        read -p "$message (y/N): " -r
        [[ "$REPLY" =~ ^[Yy]$ ]]
    fi
}

# =============================================================================
# Script Metadata
# =============================================================================

script_name() {
    basename "${BASH_SOURCE[1]:-$0}"
}

script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd
}
