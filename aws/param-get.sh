#!/bin/bash
# =============================================================================
# Check AWS Parameter Store
# =============================================================================
#
# This script:
# 1. Lists parameters by path or shows specific parameter details
# 2. Displays parameter values (with decryption for SecureString)
# 3. Shows parameter metadata
#
# Usage:
#   ./check-param-store.sh [PARAM_NAME_OR_PATH]
#   ./check-param-store.sh --list [PATH]
#
# Examples:
#   ./check-param-store.sh                        # List all parameters
#   ./check-param-store.sh /myapp/config/db_host  # Show specific parameter
#   ./check-param-store.sh --list /myapp          # List under /myapp
#   ./check-param-store.sh --list /myapp --no-decrypt
#
# Flags:
#   --list, -l         List parameters under path
#   --no-decrypt       Don't decrypt SecureString values
#   --no-recursive     Don't recurse into subpaths
#   --show-values      Show values in list mode
#
# Environment Variables:
#   AWS_REGION  - AWS region (default: ap-northeast-1)
#   AWS_PROFILE - AWS profile to use
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/aws.sh"

# =============================================================================
# Configuration
# =============================================================================

PARAM_PATH=""
LIST_MODE=false
DECRYPT=true
RECURSIVE=true
SHOW_VALUES=false
REGION="$(aws_get_region)"

# =============================================================================
# Parse Arguments
# =============================================================================

parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --list|-l)
                LIST_MODE=true
                shift
                ;;
            --no-decrypt)
                DECRYPT=false
                shift
                ;;
            --no-recursive)
                RECURSIVE=false
                shift
                ;;
            --show-values|-v)
                SHOW_VALUES=true
                shift
                ;;
            --help|-h)
                echo "Check AWS Parameter Store"
                echo ""
                echo "Usage: $0 [PARAM_NAME_OR_PATH] [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --list, -l        List parameters under path"
                echo "  --no-decrypt      Don't decrypt SecureString values"
                echo "  --no-recursive    Don't recurse into subpaths"
                echo "  --show-values, -v Show values in list mode"
                echo "  --help, -h        Show this help"
                echo ""
                echo "Examples:"
                echo "  $0                              # List all parameters"
                echo "  $0 /myapp/config/db_host        # Show specific parameter"
                echo "  $0 --list /myapp                # List under /myapp"
                echo "  $0 --list /myapp --show-values  # List with values"
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                exit 1
                ;;
            *)
                PARAM_PATH="$1"
                shift
                ;;
        esac
    done

    # Default path
    if [ -z "$PARAM_PATH" ]; then
        PARAM_PATH="/"
        LIST_MODE=true
    fi
}

# =============================================================================
# Functions
# =============================================================================

format_date() {
    local timestamp="$1"
    # Extract just the date part if it's a full timestamp
    echo "$timestamp" | cut -d'T' -f1
}

format_size() {
    local value="$1"
    echo "${#value} chars"
}

show_single_parameter() {
    local name="$1"

    if ! ssm_param_exists "$name" "$REGION"; then
        print_error "Parameter not found: $name"
        return 1
    fi

    print_section "Parameter Details"

    local info
    if [ "$DECRYPT" = true ]; then
        info=$(ssm_get_param "$name" "$REGION" true)
    else
        info=$(ssm_get_param "$name" "$REGION" false)
    fi

    local param_name=$(json_get "$info" '.Parameter.Name')
    local type=$(json_get "$info" '.Parameter.Type')
    local version=$(json_get "$info" '.Parameter.Version')
    local last_modified=$(json_get "$info" '.Parameter.LastModifiedDate')
    local arn=$(json_get "$info" '.Parameter.ARN')
    local value=$(json_get "$info" '.Parameter.Value')
    local data_type=$(json_get "$info" '.Parameter.DataType')

    echo ""
    echo "  Name:          $param_name"
    echo "  Type:          $type"
    echo "  Data Type:     ${data_type:-text}"
    echo "  Version:       $version"
    echo "  Last Modified: $last_modified"
    echo ""
    echo "  ARN:"
    echo "    $arn"
    echo ""

    if [ "$type" = "SecureString" ] && [ "$DECRYPT" = false ]; then
        echo "  Value: ********** (use without --no-decrypt to show)"
    elif [ "$type" = "SecureString" ]; then
        echo -e "  Value: ${YELLOW}$value${NC}"
        echo -e "         ${DIM}(SecureString - decrypted)${NC}"
    elif [ "$type" = "StringList" ]; then
        echo "  Value (StringList):"
        echo "$value" | tr ',' '\n' | sed 's/^/    - /'
    else
        # Handle multi-line or long values
        if [ ${#value} -gt 80 ] || [[ "$value" == *$'\n'* ]]; then
            echo "  Value:"
            echo "$value" | sed 's/^/    /'
        else
            echo "  Value: $value"
        fi
    fi
}

list_parameters() {
    local path="$1"

    print_section "Parameters: $path"

    local params
    if [ "$RECURSIVE" = true ]; then
        if [ "$DECRYPT" = true ]; then
            params=$(aws ssm get-parameters-by-path \
                --path "$path" \
                --recursive \
                --with-decryption \
                --region "$REGION" \
                --output json 2>/dev/null)
        else
            params=$(aws ssm get-parameters-by-path \
                --path "$path" \
                --recursive \
                --region "$REGION" \
                --output json 2>/dev/null)
        fi
    else
        if [ "$DECRYPT" = true ]; then
            params=$(aws ssm get-parameters-by-path \
                --path "$path" \
                --with-decryption \
                --region "$REGION" \
                --output json 2>/dev/null)
        else
            params=$(aws ssm get-parameters-by-path \
                --path "$path" \
                --region "$REGION" \
                --output json 2>/dev/null)
        fi
    fi

    local count=$(echo "$params" | jq -r '.Parameters | length')

    if [ "$count" = "0" ] || [ -z "$count" ]; then
        print_info "No parameters found under: $path"
        return 0
    fi

    print_info "Found $count parameter(s)"
    echo ""

    if [ "$SHOW_VALUES" = true ]; then
        # Detailed list with values
        echo "$params" | jq -r '.Parameters[] | "\(.Name)|\(.Type)|\(.Version)|\(.Value)"' | while IFS='|' read -r name type version value; do
            echo -e "  ${CYAN}$name${NC}"
            echo "    Type: $type | Version: $version"
            if [ "$type" = "SecureString" ]; then
                if [ "$DECRYPT" = true ]; then
                    echo -e "    Value: ${YELLOW}${value:0:50}${NC}$( [ ${#value} -gt 50 ] && echo '...' )"
                else
                    echo "    Value: **********"
                fi
            else
                if [ ${#value} -gt 60 ]; then
                    echo "    Value: ${value:0:60}..."
                else
                    echo "    Value: $value"
                fi
            fi
            echo ""
        done
    else
        # Compact list
        printf "  %-50s %-12s %s\n" "NAME" "TYPE" "VERSION"
        printf "  %-50s %-12s %s\n" "----" "----" "-------"

        echo "$params" | jq -r '.Parameters[] | "\(.Name)|\(.Type)|\(.Version)"' | while IFS='|' read -r name type version; do
            # Truncate long names
            if [ ${#name} -gt 48 ]; then
                display_name="...${name: -45}"
            else
                display_name="$name"
            fi

            if [ "$type" = "SecureString" ]; then
                printf "  %-50s ${YELLOW}%-12s${NC} %s\n" "$display_name" "$type" "v$version"
            else
                printf "  %-50s %-12s %s\n" "$display_name" "$type" "v$version"
            fi
        done
    fi
}

describe_all_parameters() {
    print_section "All Parameters (Metadata)"

    local params=$(aws ssm describe-parameters --region "$REGION" --output json 2>/dev/null)

    local count=$(echo "$params" | jq -r '.Parameters | length')

    if [ "$count" = "0" ] || [ -z "$count" ]; then
        print_info "No parameters found"
        return 0
    fi

    print_info "Found $count parameter(s)"
    echo ""

    printf "  %-45s %-12s %-10s %s\n" "NAME" "TYPE" "VERSION" "LAST MODIFIED"
    printf "  %-45s %-12s %-10s %s\n" "----" "----" "-------" "-------------"

    echo "$params" | jq -r '.Parameters[] | "\(.Name)|\(.Type)|\(.Version)|\(.LastModifiedDate)"' | while IFS='|' read -r name type version modified; do
        # Truncate long names
        if [ ${#name} -gt 43 ]; then
            display_name="...${name: -40}"
        else
            display_name="$name"
        fi

        # Format date
        mod_date=$(format_date "$modified")

        if [ "$type" = "SecureString" ]; then
            printf "  %-45s ${YELLOW}%-12s${NC} %-10s %s\n" "$display_name" "$type" "v$version" "$mod_date"
        else
            printf "  %-45s %-12s %-10s %s\n" "$display_name" "$type" "v$version" "$mod_date"
        fi
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    print_header "Check Parameter Store"

    # Prerequisites
    if ! require_aws_cli; then
        return 1
    fi
    print_info "Region: $REGION"
    echo ""

    # Determine mode
    if [ "$LIST_MODE" = true ]; then
        if [ "$PARAM_PATH" = "/" ]; then
            describe_all_parameters
        else
            list_parameters "$PARAM_PATH"
        fi
    else
        # Check if it's a path (ends with /) or a specific parameter
        if [[ "$PARAM_PATH" == */ ]]; then
            list_parameters "$PARAM_PATH"
        else
            show_single_parameter "$PARAM_PATH"
        fi
    fi

    echo ""
    return 0
}

main "$@"
exit $?
