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
    return 0
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

# =============================================================================
# Environment Loading
# =============================================================================

load_env() {
    local env_file="${1:-}"
    local script_dir

    # Get the directory of the calling script
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)"

    # If no file specified, try common locations
    if [ -z "$env_file" ]; then
        if [ -f "$script_dir/.env" ]; then
            env_file="$script_dir/.env"
        elif [ -f "$script_dir/../.env" ]; then
            env_file="$script_dir/../.env"
        else
            return 1
        fi
    fi

    if [ -f "$env_file" ]; then
        # shellcheck disable=SC1090
        source "$env_file"
        print_debug "Loaded env from: $env_file"
        return 0
    fi

    return 1
}

# =============================================================================
# URL/Connection Utilities
# =============================================================================

parse_postgres_url() {
    local url="$1"

    # Remove postgresql:// or postgres:// prefix
    local stripped="${url#postgresql://}"
    stripped="${stripped#postgres://}"

    # Extract user:password@host/database
    local userinfo="${stripped%%@*}"
    local hostpart="${stripped#*@}"

    # Extract user and password
    PG_USER="${userinfo%%:*}"
    PG_PASS="${userinfo#*:}"

    # Extract host:port/database?params
    local hostdb="${hostpart%%\?*}"
    PG_PARAMS="${hostpart#*\?}"
    [ "$PG_PARAMS" = "$hostpart" ] && PG_PARAMS=""

    # Extract host:port and database
    local hostport="${hostdb%%/*}"
    PG_DATABASE="${hostdb#*/}"

    # Extract host and port
    if [[ "$hostport" == *:* ]]; then
        PG_HOST="${hostport%%:*}"
        PG_PORT="${hostport#*:}"
    else
        PG_HOST="$hostport"
        PG_PORT="5432"
    fi
}

parse_mongo_url() {
    local url="$1"

    # Check protocol
    if [[ "$url" == mongodb+srv://* ]]; then
        MONGO_PROTOCOL="mongodb+srv"
        local stripped="${url#mongodb+srv://}"
    else
        MONGO_PROTOCOL="mongodb"
        local stripped="${url#mongodb://}"
    fi

    # Extract user:password@host/database
    local userinfo="${stripped%%@*}"
    local hostpart="${stripped#*@}"

    # Extract user and password
    if [[ "$userinfo" == *:* ]]; then
        MONGO_USER="${userinfo%%:*}"
        MONGO_PASS="${userinfo#*:}"
    else
        MONGO_USER="$userinfo"
        MONGO_PASS=""
    fi

    # Extract host/database?params
    local hostdb="${hostpart%%\?*}"
    MONGO_PARAMS="${hostpart#*\?}"
    [ "$MONGO_PARAMS" = "$hostpart" ] && MONGO_PARAMS=""

    # Extract host and database
    if [[ "$hostdb" == */* ]]; then
        MONGO_HOST="${hostdb%%/*}"
        MONGO_DATABASE="${hostdb#*/}"
    else
        MONGO_HOST="$hostdb"
        MONGO_DATABASE=""
    fi
}

# =============================================================================
# Discord Utilities
# =============================================================================

validate_discord_webhook() {
    local url="$1"

    if [[ "$url" =~ ^https://discord\.com/api/webhooks/[0-9]+/.+ ]] || \
       [[ "$url" =~ ^https://discordapp\.com/api/webhooks/[0-9]+/.+ ]]; then
        return 0
    fi
    return 1
}

discord_send_message() {
    local webhook_url="$1"
    local content="$2"

    local payload="{\"content\": \"$content\"}"

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook_url" 2>&1)

    local http_code=$(echo "$response" | tail -1)

    [ "$http_code" = "204" ] || [ "$http_code" = "200" ]
}

discord_send_embed() {
    local webhook_url="$1"
    local title="$2"
    local description="$3"
    local color="${4:-5814783}"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local hostname=$(hostname 2>/dev/null || echo "unknown")

    local payload=$(cat <<EOF
{
    "embeds": [{
        "title": "$title",
        "description": "$description",
        "color": $color,
        "timestamp": "$timestamp",
        "footer": {"text": "$hostname"}
    }]
}
EOF
)

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook_url" 2>&1)

    local http_code=$(echo "$response" | tail -1)

    [ "$http_code" = "204" ] || [ "$http_code" = "200" ]
}
