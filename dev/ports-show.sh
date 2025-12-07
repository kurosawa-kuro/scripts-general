#!/bin/bash
# ============================================================================
# Check All Development Ports Script
# ============================================================================
# Purpose: Check processes using development ports and dev servers
# Usage: ./check-all-dev-port.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/../lib/core.sh"

print_header "Checking Development Ports and Processes"

# Track findings
FOUND_PROCESSES=0

# ============================================================================
# Function: Check process on port
# ============================================================================
check_port() {
    local port=$1
    local description=$2

    echo -e "${CYAN}Port $port${NC} ($description)"

    local pids=$(get_pids_on_port "$port")

    if [ -z "$pids" ]; then
        echo -e "  ${GREEN}[FREE]${NC} No process using this port"
    else
        FOUND_PROCESSES=1
        echo -e "  ${YELLOW}[IN USE]${NC} Process(es) found:"
        for pid in $pids; do
            if [ -f "/proc/$pid/cmdline" ]; then
                local cmd=$(cat /proc/$pid/cmdline | tr '\0' ' ' 2>/dev/null | head -c 80 || echo "unknown")
                local user=$(ps -o user= -p $pid 2>/dev/null || echo "unknown")
                echo -e "    PID: ${CYAN}$pid${NC} | User: $user"
                echo -e "    Cmd: $cmd"
            else
                echo -e "    PID: ${CYAN}$pid${NC}"
            fi
        done
    fi
    echo ""
}

# ============================================================================
# Function: Check process by pattern
# ============================================================================
check_process_by_pattern() {
    local pattern=$1
    local description=$2

    echo -e "${CYAN}$description${NC} (pattern: $pattern)"

    local pids=$(get_pids_by_pattern "$pattern")

    if [ -z "$pids" ]; then
        echo -e "  ${GREEN}[NOT RUNNING]${NC} No matching process"
    else
        FOUND_PROCESSES=1
        echo -e "  ${YELLOW}[RUNNING]${NC} Process(es) found:"
        for pid in $pids; do
            if [ -f "/proc/$pid/cmdline" ]; then
                local cmd=$(cat /proc/$pid/cmdline | tr '\0' ' ' 2>/dev/null | head -c 80 || echo "unknown")
                local user=$(ps -o user= -p $pid 2>/dev/null || echo "unknown")
                echo -e "    PID: ${CYAN}$pid${NC} | User: $user"
                echo -e "    Cmd: $cmd"
            else
                echo -e "    PID: ${CYAN}$pid${NC}"
            fi
        done
    fi
    echo ""
}

# ============================================================================
# Check common development ports
# ============================================================================
print_section "Checking Ports"

check_port 3000 "Frontend / Next.js / React"
check_port 3001 "Frontend alternate"
check_port 5173 "Vite dev server"
check_port 8000 "Backend / Python / FastAPI"
check_port 8080 "Backend alternate / Proxy"

# ============================================================================
# Check development server processes
# ============================================================================
print_section "Checking Dev Server Processes"

check_process_by_pattern "next dev" "Next.js dev server"
check_process_by_pattern "vite" "Vite dev server"
check_process_by_pattern "nodemon" "Nodemon"
check_process_by_pattern "ts-node" "ts-node"

# ============================================================================
# Check test processes
# ============================================================================
print_section "Checking Test Processes"

check_process_by_pattern "playwright" "Playwright"
check_process_by_pattern "jest" "Jest"
check_process_by_pattern "vitest" "Vitest"

# ============================================================================
# Summary
# ============================================================================
echo ""
print_header "Summary"
if [ $FOUND_PROCESSES -eq 1 ]; then
    print_warning "Some development processes are running"
    print_info "To kill them: ./kill-all-dev-port.sh"
else
    print_success "All development ports are free"
fi
