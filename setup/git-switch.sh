#!/bin/bash
# =============================================================================
# Git Config Switcher
# =============================================================================
#
# This script:
# 1. Manages multiple Git user profiles (work/personal)
# 2. Switches between profiles easily
# 3. Stores profiles in ~/.gitconfig-profiles/
#
# Usage:
#   ./setup-git-config.sh [PROFILE_NAME]
#   ./setup-git-config.sh --list
#   ./setup-git-config.sh --current
#   ./setup-git-config.sh --add PROFILE_NAME
#
# Examples:
#   ./setup-git-config.sh work
#   ./setup-git-config.sh personal
#   ./setup-git-config.sh --add company
#
# Flags:
#   --list, -l     List all available profiles
#   --current, -c  Show current git config
#   --add, -a      Add a new profile interactively
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

# =============================================================================
# Configuration
# =============================================================================

PROFILES_DIR="$HOME/.gitconfig-profiles"
PROFILE_NAME=""
SHOW_LIST=false
SHOW_CURRENT=false
ADD_PROFILE=false

# =============================================================================
# Parse Arguments
# =============================================================================

parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --list|-l)
                SHOW_LIST=true
                shift
                ;;
            --current|-c)
                SHOW_CURRENT=true
                shift
                ;;
            --add|-a)
                ADD_PROFILE=true
                if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then
                    PROFILE_NAME="$2"
                    shift
                fi
                shift
                ;;
            --help|-h)
                echo "Git Config Switcher"
                echo ""
                echo "Usage: $0 [PROFILE_NAME] [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --list, -l     List all available profiles"
                echo "  --current, -c  Show current git config"
                echo "  --add, -a      Add a new profile interactively"
                echo "  --help, -h     Show this help"
                echo ""
                echo "Examples:"
                echo "  $0 work"
                echo "  $0 personal"
                echo "  $0 --add company"
                exit 0
                ;;
            *)
                PROFILE_NAME="$1"
                shift
                ;;
        esac
    done
}

# =============================================================================
# Functions
# =============================================================================

ensure_profiles_dir() {
    if [ ! -d "$PROFILES_DIR" ]; then
        mkdir -p "$PROFILES_DIR"
        print_info "Created profiles directory: $PROFILES_DIR"
    fi
}

list_profiles() {
    if [ ! -d "$PROFILES_DIR" ]; then
        return
    fi

    for file in "$PROFILES_DIR"/*.conf; do
        if [ -f "$file" ]; then
            basename "$file" .conf
        fi
    done
}

show_profiles() {
    print_section "Available Git Profiles"

    local profiles=$(list_profiles)

    if [ -z "$profiles" ]; then
        print_info "No profiles found"
        print_info "Create one with: $0 --add PROFILE_NAME"
        return 0
    fi

    local current_name=$(git config --global user.name 2>/dev/null)
    local current_email=$(git config --global user.email 2>/dev/null)

    echo "$profiles" | while read -r profile; do
        local profile_file="$PROFILES_DIR/${profile}.conf"
        if [ -f "$profile_file" ]; then
            local name=$(grep "^name=" "$profile_file" | cut -d= -f2-)
            local email=$(grep "^email=" "$profile_file" | cut -d= -f2-)

            if [ "$name" = "$current_name" ] && [ "$email" = "$current_email" ]; then
                echo -e "  ${GREEN}* $profile${NC} ($name <$email>)"
            else
                echo "    $profile ($name <$email>)"
            fi
        fi
    done
}

show_current() {
    print_section "Current Git Config"

    local name=$(git config --global user.name 2>/dev/null)
    local email=$(git config --global user.email 2>/dev/null)
    local signingkey=$(git config --global user.signingkey 2>/dev/null)
    local gpgsign=$(git config --global commit.gpgsign 2>/dev/null)

    if [ -z "$name" ] && [ -z "$email" ]; then
        print_warning "No git user configured"
        print_info "Run: $0 --add PROFILE_NAME"
        return 0
    fi

    print_info "Name: ${name:-not set}"
    print_info "Email: ${email:-not set}"

    if [ -n "$signingkey" ]; then
        print_info "Signing Key: $signingkey"
        print_info "GPG Sign: ${gpgsign:-false}"
    fi
}

add_profile() {
    local profile_name="$1"

    if [ -z "$profile_name" ]; then
        echo -n "Profile name: "
        read -r profile_name
    fi

    if [ -z "$profile_name" ]; then
        print_error "Profile name is required"
        return 1
    fi

    ensure_profiles_dir

    local profile_file="$PROFILES_DIR/${profile_name}.conf"

    if [ -f "$profile_file" ]; then
        print_warning "Profile '$profile_name' already exists"
        if ! confirm "Overwrite?" "n"; then
            return 0
        fi
    fi

    print_section "Create Profile: $profile_name"

    # Get current values as defaults
    local current_name=$(git config --global user.name 2>/dev/null)
    local current_email=$(git config --global user.email 2>/dev/null)

    echo -n "Name [$current_name]: "
    read -r name
    name="${name:-$current_name}"

    echo -n "Email [$current_email]: "
    read -r email
    email="${email:-$current_email}"

    echo -n "GPG Signing Key (optional): "
    read -r signingkey

    # Save profile
    cat > "$profile_file" <<EOF
name=$name
email=$email
signingkey=$signingkey
EOF

    print_success "Profile '$profile_name' saved"
    print_info "Switch to it: $0 $profile_name"
}

switch_profile() {
    local profile_name="$1"

    local profile_file="$PROFILES_DIR/${profile_name}.conf"

    if [ ! -f "$profile_file" ]; then
        print_error "Profile '$profile_name' not found"
        echo ""
        show_profiles
        return 1
    fi

    print_section "Switching to Profile: $profile_name"

    # Read profile
    local name=$(grep "^name=" "$profile_file" | cut -d= -f2-)
    local email=$(grep "^email=" "$profile_file" | cut -d= -f2-)
    local signingkey=$(grep "^signingkey=" "$profile_file" | cut -d= -f2-)

    # Apply settings
    git config --global user.name "$name"
    print_success "Set user.name: $name"

    git config --global user.email "$email"
    print_success "Set user.email: $email"

    if [ -n "$signingkey" ]; then
        git config --global user.signingkey "$signingkey"
        git config --global commit.gpgsign true
        print_success "Set signing key: $signingkey"
    else
        git config --global --unset user.signingkey 2>/dev/null || true
        git config --global --unset commit.gpgsign 2>/dev/null || true
        print_info "GPG signing disabled"
    fi

    echo ""
    print_success "Switched to profile: $profile_name"
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    print_header "Git Config Manager"

    # Handle modes
    if [ "$ADD_PROFILE" = true ]; then
        add_profile "$PROFILE_NAME"
        return $?
    fi

    if [ "$SHOW_LIST" = true ]; then
        show_profiles
        return 0
    fi

    if [ "$SHOW_CURRENT" = true ]; then
        show_current
        return 0
    fi

    if [ -n "$PROFILE_NAME" ]; then
        switch_profile "$PROFILE_NAME"
        return $?
    fi

    # Default: show current and list
    show_current
    echo ""
    show_profiles
}

main "$@"
exit $?
