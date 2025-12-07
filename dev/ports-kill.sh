#!/bin/bash
# ============================================================================
# Kill All Development Ports Script
# ============================================================================
# Purpose: Kill processes using development ports and dev servers
# Usage: ./kill-all-dev-port.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

print_header "Killing Development Ports and Processes"

# ============================================================================
# Function: Kill process on port
# ============================================================================
kill_port() {
    local port=$1
    local description=$2

    print_info "Checking port $port ($description)..."

    local pids=$(get_pids_on_port "$port")

    if [ -z "$pids" ]; then
        print_success "No process found on port $port"
        return 0
    fi

    # Display process information
    print_warning "Found process(es) using port $port:"
    for pid in $pids; do
        if [ -f "/proc/$pid/cmdline" ]; then
            local cmd=$(cat /proc/$pid/cmdline | tr '\0' ' ' 2>/dev/null | head -c 80 || echo "unknown")
            local user=$(ps -o user= -p $pid 2>/dev/null || echo "unknown")
            echo "    PID: $pid, User: $user, Command: $cmd"
        else
            echo "    PID: $pid"
        fi
    done

    # Kill processes
    kill_pids "$pids" 9

    # Verify port is free
    sleep 1
    local remaining=$(get_pids_on_port "$port")

    if [ -z "$remaining" ]; then
        print_success "Port $port is now free"
    else
        print_warning "Some processes still remain on port $port"
    fi

    echo ""
    return 0
}

# ============================================================================
# Function: Kill process by pattern
# ============================================================================
kill_process_by_pattern() {
    local pattern=$1
    local description=$2

    print_info "Checking for processes matching pattern: $pattern ($description)..."

    if ! command -v pkill &> /dev/null; then
        print_error "pkill not found. Cannot kill processes matching '$pattern'."
        echo ""
        return 1
    fi

    local pids=$(get_pids_by_pattern "$pattern")

    if [ -z "$pids" ]; then
        print_success "No process found matching pattern '$pattern'"
        echo ""
        return 0
    fi

    # Display process information
    print_warning "Found process(es) matching pattern '$pattern':"
    for pid in $pids; do
        if [ -f "/proc/$pid/cmdline" ]; then
            local cmd=$(cat /proc/$pid/cmdline | tr '\0' ' ' 2>/dev/null | head -c 80 || echo "unknown")
            local user=$(ps -o user= -p $pid 2>/dev/null || echo "unknown")
            echo "    PID: $pid, User: $user, Command: $cmd"
        else
            echo "    PID: $pid"
        fi
    done

    # Kill processes
    if pkill -f "$pattern" 2>/dev/null; then
        sleep 1
        # Verify processes are killed
        if [ -z "$(get_pids_by_pattern "$pattern")" ]; then
            print_success "Successfully killed all processes matching '$pattern'"
        else
            print_warning "Some processes still remain matching '$pattern'"
            print_info "Try with sudo: sudo pkill -f \"$pattern\""
        fi
    else
        print_error "Failed to kill processes matching '$pattern'"
        print_info "Try with sudo: sudo pkill -f \"$pattern\""
    fi

    echo ""
    return 0
}

# ============================================================================
# Kill common development ports
# ============================================================================
print_section "Killing Port Processes"

kill_port 3000 "Frontend (Node.js default)"
kill_port 8000 "Backend (Python HTTP server)"

# ============================================================================
# Kill development server processes
# ============================================================================
print_section "Killing Dev Server Processes"

kill_process_by_pattern "next dev" "Next.js development server"

# ============================================================================
# Kill test processes
# ============================================================================
print_section "Killing Test Processes"

kill_process_by_pattern "playwright test" "Playwright test processes"
kill_process_by_pattern "chromium_headless_shell" "Playwright Chromium headless processes"

# ============================================================================
# Summary
# ============================================================================
echo ""
print_success "Finished checking development ports"
