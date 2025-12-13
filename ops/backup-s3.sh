#!/bin/bash
# =============================================================================
# Backup to S3
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core.sh"

SOURCE="${1:-}"
BUCKET="${2:-}"
PREFIX="${3:-backups}"

print_usage() {
    echo "Backup to S3"
    echo ""
    echo "Usage:"
    echo "  $0 SOURCE BUCKET [PREFIX]"
    echo "  $0 ./data my-bucket backups"
    echo "  $0 --list BUCKET [PREFIX]"
    echo "  $0 --help"
    echo ""
    echo "Options:"
    echo "  --compress     Compress before upload (tar.gz)"
    echo "  --sync         Use sync instead of copy"
}

COMPRESS=false
SYNC_MODE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --compress|-c) COMPRESS=true; shift ;;
            --sync|-s) SYNC_MODE=true; shift ;;
            --list|-l) list_backups "$2" "$3"; exit 0 ;;
            --help|-h) print_usage; exit 0 ;;
            *)
                if [ -z "$SOURCE" ]; then SOURCE="$1"
                elif [ -z "$BUCKET" ]; then BUCKET="$1"
                else PREFIX="$1"
                fi
                shift
                ;;
        esac
    done
}

list_backups() {
    local bucket="$1"
    local prefix="${2:-backups}"

    print_header "Backups in s3://$bucket/$prefix"
    aws s3 ls "s3://$bucket/$prefix/" --recursive --human-readable
}

backup() {
    print_header "Backup to S3"

    if [ -z "$SOURCE" ] || [ -z "$BUCKET" ]; then
        print_error "Source and bucket required"
        print_usage
        return 1
    fi

    if [ ! -e "$SOURCE" ]; then
        print_error "Source not found: $SOURCE"
        return 1
    fi

    local timestamp=$(date +%Y%m%d-%H%M%S)
    local source_name=$(basename "$SOURCE")

    print_info "Source: $SOURCE"
    print_info "Bucket: s3://$BUCKET/$PREFIX"

    if [ "$COMPRESS" = true ]; then
        print_section "Compressing"
        local archive="/tmp/${source_name}-${timestamp}.tar.gz"
        tar -czf "$archive" -C "$(dirname "$SOURCE")" "$source_name"
        print_success "Created: $archive"

        print_section "Uploading"
        aws s3 cp "$archive" "s3://$BUCKET/$PREFIX/"
        rm -f "$archive"
    elif [ "$SYNC_MODE" = true ]; then
        print_section "Syncing"
        aws s3 sync "$SOURCE" "s3://$BUCKET/$PREFIX/$source_name/"
    else
        print_section "Uploading"
        if [ -d "$SOURCE" ]; then
            aws s3 cp "$SOURCE" "s3://$BUCKET/$PREFIX/$source_name-$timestamp/" --recursive
        else
            aws s3 cp "$SOURCE" "s3://$BUCKET/$PREFIX/${source_name}-$timestamp"
        fi
    fi

    print_success "Backup completed"

    echo ""
    print_info "List backups: $0 --list $BUCKET $PREFIX"
}

parse_args "$@"
backup
