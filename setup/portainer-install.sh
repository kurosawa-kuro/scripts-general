#!/bin/bash
# =============================================================================
# Portainer Setup Script
# =============================================================================
# Purpose: Install and manage Portainer CE (Docker management UI)
# Usage:
#   bash scripts/setup/setup-portainer.sh                # Install/Start Portainer
#   bash scripts/setup/setup-portainer.sh --stop         # Stop Portainer
#   bash scripts/setup/setup-portainer.sh --restart      # Restart Portainer
#   bash scripts/setup/setup-portainer.sh --uninstall    # Remove Portainer completely
#   bash scripts/setup/setup-portainer.sh --status       # Check Portainer status
#
# Portainer Access:
#   http://localhost:9000
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
PORTAINER_IMAGE="portainer/portainer-ce:latest"
PORTAINER_CONTAINER="portainer"
PORTAINER_VOLUME="portainer_data"
PORTAINER_PORT_UI=9000
PORTAINER_PORT_EDGE=8000

# =============================================================================
# Functions
# =============================================================================

print_header() {
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}--- $1 ---${NC}"
}

print_usage() {
    echo "Portainer Setup Script"
    echo ""
    echo "Usage:"
    echo "  $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  (no args)       Install/Start Portainer (default)"
    echo "  --start         Start Portainer"
    echo "  --stop          Stop Portainer"
    echo "  --restart       Restart Portainer"
    echo "  --uninstall     Remove Portainer completely"
    echo "  --status        Check Portainer status"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install and start Portainer"
    echo "  $0 --stop             # Stop Portainer"
    echo "  $0 --restart          # Restart Portainer"
    echo "  $0 --uninstall        # Remove Portainer"
    echo ""
    echo "Access:"
    echo "  UI:   http://localhost:$PORTAINER_PORT_UI"
    echo "  Edge: http://localhost:$PORTAINER_PORT_EDGE"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗${NC} Docker not found. Please install Docker."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        echo -e "${RED}✗${NC} Docker daemon is not running. Please start Docker."
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Docker is running"
}

check_portainer_exists() {
    docker ps -a --filter "name=^${PORTAINER_CONTAINER}$" --format '{{.Names}}' | grep -q "^${PORTAINER_CONTAINER}$"
}

check_portainer_running() {
    docker ps --filter "name=^${PORTAINER_CONTAINER}$" --format '{{.Names}}' | grep -q "^${PORTAINER_CONTAINER}$"
}

show_portainer_status() {
    print_section "Portainer Status"

    if check_portainer_exists; then
        echo -e "${MAGENTA}Container:${NC} EXISTS"

        if check_portainer_running; then
            echo -e "${MAGENTA}Status:${NC} ${GREEN}RUNNING${NC}"

            # Show container details
            docker ps --filter "name=^${PORTAINER_CONTAINER}$" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

            echo ""
            echo -e "${GREEN}Access Portainer:${NC}"
            echo -e "  UI:   ${CYAN}http://localhost:$PORTAINER_PORT_UI${NC}"
            echo -e "  Edge: ${CYAN}http://localhost:$PORTAINER_PORT_EDGE${NC}"
        else
            echo -e "${MAGENTA}Status:${NC} ${YELLOW}STOPPED${NC}"

            # Show stopped container
            docker ps -a --filter "name=^${PORTAINER_CONTAINER}$" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}"
        fi
    else
        echo -e "${YELLOW}⚠${NC}  Portainer is not installed"
    fi

    echo ""

    # Check volume
    if docker volume ls | grep -q "^local.*${PORTAINER_VOLUME}$"; then
        echo -e "${MAGENTA}Volume:${NC} EXISTS (${PORTAINER_VOLUME})"
    else
        echo -e "${MAGENTA}Volume:${NC} NOT FOUND"
    fi
}

pull_portainer_image() {
    print_section "Pulling Portainer Image"

    echo -e "${YELLOW}⏳ Pulling latest Portainer CE image...${NC}"
    docker pull $PORTAINER_IMAGE

    echo -e "${GREEN}✓${NC} Image pulled successfully"
}

create_portainer_volume() {
    print_section "Creating Portainer Volume"

    if docker volume ls | grep -q "^local.*${PORTAINER_VOLUME}$"; then
        echo -e "${YELLOW}⚠${NC}  Volume '${PORTAINER_VOLUME}' already exists"
    else
        echo -e "${YELLOW}⏳ Creating volume: ${PORTAINER_VOLUME}${NC}"
        docker volume create $PORTAINER_VOLUME
        echo -e "${GREEN}✓${NC} Volume created successfully"
    fi
}

remove_existing_container() {
    if check_portainer_exists; then
        echo -e "${YELLOW}⏳ Removing existing Portainer container...${NC}"

        if check_portainer_running; then
            docker stop $PORTAINER_CONTAINER 2>/dev/null || true
        fi

        docker rm $PORTAINER_CONTAINER 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Existing container removed"
    fi
}

start_portainer_container() {
    print_section "Starting Portainer Container"

    echo -e "${YELLOW}⏳ Starting Portainer container...${NC}"

    docker run -d \
        -p ${PORTAINER_PORT_UI}:9000 \
        -p ${PORTAINER_PORT_EDGE}:8000 \
        --name $PORTAINER_CONTAINER \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v ${PORTAINER_VOLUME}:/data \
        $PORTAINER_IMAGE

    echo -e "${GREEN}✓${NC} Portainer container started successfully"
}

install_portainer() {
    print_header "Installing Portainer"

    check_docker

    # Check if already running
    if check_portainer_running; then
        echo -e "${YELLOW}⚠${NC}  Portainer is already running"
        echo ""
        show_portainer_status
        return 0
    fi

    # Pull latest image
    pull_portainer_image

    # Create volume
    create_portainer_volume

    # Remove existing container (if exists)
    remove_existing_container

    # Start container
    start_portainer_container

    # Wait for container to start
    echo ""
    echo -e "${YELLOW}⏳ Waiting for Portainer to start...${NC}"
    sleep 3

    # Show status
    echo ""
    show_portainer_status

    echo ""
    echo -e "${GREEN}${BOLD}✅ Portainer installation completed!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Open browser: ${YELLOW}http://localhost:$PORTAINER_PORT_UI${NC}"
    echo -e "  2. Create admin user (first-time setup)"
    echo -e "  3. Connect to local Docker environment"
}

stop_portainer() {
    print_header "Stopping Portainer"

    if ! check_portainer_exists; then
        echo -e "${YELLOW}⚠${NC}  Portainer is not installed"
        exit 0
    fi

    if ! check_portainer_running; then
        echo -e "${YELLOW}⚠${NC}  Portainer is already stopped"
        exit 0
    fi

    echo -e "${YELLOW}⏳ Stopping Portainer...${NC}"
    docker stop $PORTAINER_CONTAINER

    echo -e "${GREEN}✓${NC} Portainer stopped successfully"
}

start_portainer() {
    print_header "Starting Portainer"

    if ! check_portainer_exists; then
        echo -e "${YELLOW}⚠${NC}  Portainer is not installed. Installing now..."
        install_portainer
        return 0
    fi

    if check_portainer_running; then
        echo -e "${YELLOW}⚠${NC}  Portainer is already running"
        show_portainer_status
        return 0
    fi

    echo -e "${YELLOW}⏳ Starting Portainer...${NC}"
    docker start $PORTAINER_CONTAINER

    echo ""
    echo -e "${GREEN}✓${NC} Portainer started successfully"

    # Wait and show status
    sleep 2
    echo ""
    show_portainer_status
}

restart_portainer() {
    print_header "Restarting Portainer"

    if ! check_portainer_exists; then
        echo -e "${YELLOW}⚠${NC}  Portainer is not installed"
        exit 0
    fi

    echo -e "${YELLOW}⏳ Restarting Portainer...${NC}"
    docker restart $PORTAINER_CONTAINER

    echo ""
    echo -e "${GREEN}✓${NC} Portainer restarted successfully"

    # Wait and show status
    sleep 2
    echo ""
    show_portainer_status
}

uninstall_portainer() {
    print_header "Uninstalling Portainer"

    if ! check_portainer_exists; then
        echo -e "${YELLOW}⚠${NC}  Portainer is not installed"

        # Check if volume exists
        if docker volume ls | grep -q "^local.*${PORTAINER_VOLUME}$"; then
            echo ""
            read -p "Volume '${PORTAINER_VOLUME}' exists. Remove it? (y/N): " -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker volume rm $PORTAINER_VOLUME
                echo -e "${GREEN}✓${NC} Volume removed"
            fi
        fi

        exit 0
    fi

    # Confirm uninstall
    echo -e "${YELLOW}⚠${NC}  This will remove Portainer container and optionally the data volume."
    echo ""
    read -p "Are you sure you want to uninstall Portainer? (y/N): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
        exit 0
    fi

    # Stop container
    if check_portainer_running; then
        echo -e "${YELLOW}⏳ Stopping Portainer...${NC}"
        docker stop $PORTAINER_CONTAINER
    fi

    # Remove container
    echo -e "${YELLOW}⏳ Removing Portainer container...${NC}"
    docker rm $PORTAINER_CONTAINER
    echo -e "${GREEN}✓${NC} Container removed"

    # Ask about volume
    echo ""
    read -p "Remove data volume '${PORTAINER_VOLUME}'? (y/N): " -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume rm $PORTAINER_VOLUME
        echo -e "${GREEN}✓${NC} Volume removed"
    else
        echo -e "${YELLOW}⚠${NC}  Volume '${PORTAINER_VOLUME}' preserved"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}✅ Portainer uninstalled successfully!${NC}"
}

# =============================================================================
# Parse Arguments
# =============================================================================

COMMAND="install"

if [ $# -gt 0 ]; then
    case $1 in
        --start)
            COMMAND="start"
            ;;
        --stop)
            COMMAND="stop"
            ;;
        --restart)
            COMMAND="restart"
            ;;
        --uninstall)
            COMMAND="uninstall"
            ;;
        --status)
            COMMAND="status"
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
            print_usage
            exit 1
            ;;
    esac
fi

# =============================================================================
# Main Script
# =============================================================================

case $COMMAND in
    install)
        install_portainer
        ;;
    start)
        start_portainer
        ;;
    stop)
        stop_portainer
        ;;
    restart)
        restart_portainer
        ;;
    status)
        print_header "Portainer Status"
        check_docker
        show_portainer_status
        ;;
    uninstall)
        uninstall_portainer
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        exit 1
        ;;
esac
