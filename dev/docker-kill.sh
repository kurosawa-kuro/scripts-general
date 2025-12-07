#!/bin/bash

# ============================================================================
# Kill All Docker Containers and Clusters Script
# ============================================================================
# Purpose: Stop and remove all Docker containers, clusters, and related resources
# Usage: ./kill-all-docker.sh

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Killing All Docker Containers & Clusters${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# Check if Docker is installed and running
# ============================================================================
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗${NC} Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}✗${NC} Docker daemon is not running"
    exit 1
fi

# ============================================================================
# Step 1: Stop all running containers
# ============================================================================
echo -e "${YELLOW}Step 1: Stopping all running containers...${NC}"
RUNNING_CONTAINERS=$(docker ps -q)
if [ -z "$RUNNING_CONTAINERS" ]; then
    echo -e "  ${GREEN}✓${NC} No running containers found"
else
    CONTAINER_COUNT=$(echo "$RUNNING_CONTAINERS" | wc -l)
    echo -e "  ${BLUE}Found $CONTAINER_COUNT running container(s)${NC}"
    docker stop $RUNNING_CONTAINERS 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} All running containers stopped"
fi
echo ""

# ============================================================================
# Step 2: Stop all Docker Compose projects
# ============================================================================
echo -e "${YELLOW}Step 2: Stopping all Docker Compose projects...${NC}"
if command -v docker compose &> /dev/null; then
    # Find all docker-compose.yml files and stop them
    COMPOSE_FILES=$(find /home/wsl/repos/eks-secure-mlops -name "docker-compose*.yml" -o -name "compose*.yml" 2>/dev/null || true)
    if [ -z "$COMPOSE_FILES" ]; then
        echo -e "  ${GREEN}✓${NC} No Docker Compose files found"
    else
        while IFS= read -r compose_file; do
            if [ -f "$compose_file" ]; then
                COMPOSE_DIR=$(dirname "$compose_file")
                echo -e "  ${BLUE}Stopping project in: $COMPOSE_DIR${NC}"
                (cd "$COMPOSE_DIR" && docker compose down --remove-orphans 2>/dev/null || true)
            fi
        done <<< "$COMPOSE_FILES"
        echo -e "  ${GREEN}✓${NC} All Docker Compose projects stopped"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Docker Compose not found, skipping"
fi
echo ""

# ============================================================================
# Step 3: Remove all containers (stopped and running)
# ============================================================================
echo -e "${YELLOW}Step 3: Removing all containers...${NC}"
ALL_CONTAINERS=$(docker ps -aq)
if [ -z "$ALL_CONTAINERS" ]; then
    echo -e "  ${GREEN}✓${NC} No containers found"
else
    CONTAINER_COUNT=$(echo "$ALL_CONTAINERS" | wc -l)
    echo -e "  ${BLUE}Found $CONTAINER_COUNT container(s)${NC}"
    docker rm -f $ALL_CONTAINERS 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} All containers removed"
fi
echo ""

# ============================================================================
# Step 4: Remove all unused networks
# ============================================================================
echo -e "${YELLOW}Step 4: Removing unused networks...${NC}"
docker network prune -f >/dev/null 2>&1 || true
echo -e "  ${GREEN}✓${NC} Unused networks removed"
echo ""

# ============================================================================
# Step 5: Remove all unused volumes (optional - commented out by default)
# ============================================================================
# Uncomment the following section if you want to remove volumes as well
# WARNING: This will delete all unused volumes, including data!
# echo -e "${YELLOW}Step 5: Removing unused volumes...${NC}"
# docker volume prune -f >/dev/null 2>&1 || true
# echo -e "  ${GREEN}✓${NC} Unused volumes removed"
# echo ""

# ============================================================================
# Step 6: Remove all unused images (optional - commented out by default)
# ============================================================================
# Uncomment the following section if you want to remove unused images as well
# WARNING: This will delete all unused images!
# echo -e "${YELLOW}Step 6: Removing unused images...${NC}"
# docker image prune -a -f >/dev/null 2>&1 || true
# echo -e "  ${GREEN}✓${NC} Unused images removed"
# echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ All Docker containers and clusters stopped and removed${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Remaining Docker resources:"
echo -n "  Containers: "
docker ps -aq | wc -l
echo -n "  Networks: "
docker network ls -q | wc -l
echo -n "  Images: "
docker images -q | wc -l
echo ""

