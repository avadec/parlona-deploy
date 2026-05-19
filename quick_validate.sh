#!/bin/bash
#
# Quick start helper for VoiceCore validation
# Guides users through the validation process
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "============================================================"
echo "  VoiceCore Validation - Quick Start"
echo "============================================================"
echo -e "${NC}"
echo ""

# Step 1: Check .env file
echo -e "${BLUE}Step 1: Checking configuration...${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"
else
    echo -e "${YELLOW}⚠${NC} .env file not found"
    echo ""
    echo "Creating from .env.example..."
    cp .env.example .env
    echo -e "${GREEN}✓${NC} Created .env file"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Edit .env file with your settings before continuing!${NC}"
    echo ""
    read -p "Press Enter after you've edited .env, or Ctrl+C to cancel..."
fi
echo ""

# Step 2: Check Docker
echo -e "${BLUE}Step 2: Checking Docker...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Docker is not running"
    echo ""
    echo "Please start Docker first:"
    echo "  - macOS: Open Docker Desktop"
    echo "  - Linux: sudo systemctl start docker"
    echo "  - Windows: Open Docker Desktop"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker is running"
echo ""

# Step 3: Check if services are running
echo -e "${BLUE}Step 3: Checking VoiceCore services...${NC}"
RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '(stt_service|summary_service|call_analytics_api)' || true)

if [ -z "$RUNNING" ]; then
    echo -e "${YELLOW}⚠${NC} VoiceCore services are not running"
    echo ""
    echo "Choose an option:"
    echo "  1. Start services with Docker (recommended)"
    echo "  2. Validate locally (requires Python venv)"
    echo "  3. Exit"
    echo ""
    read -p "Enter choice (1/2/3): " choice
    
    case $choice in
        1)
            echo ""
            echo -e "${BLUE}Starting VoiceCore services...${NC}"
            docker compose up -d
            echo ""
            echo "Waiting for services to start..."
            sleep 5
            echo ""
            
            # Verify services started
            RUNNING=$(docker ps --format '{{.Names}}' | grep -E '(stt_service|summary_service|call_analytics_api)' || true)
            if [ -z "$RUNNING" ]; then
                echo -e "${RED}✗${NC} Services failed to start"
                echo "Check logs: docker compose logs"
                exit 1
            fi
            echo -e "${GREEN}✓${NC} Services are running"
            echo ""
            
            # Run validation
            echo -e "${BLUE}Running validation...${NC}"
            echo ""
            ./validate_config.sh "$@"
            ;;
        2)
            echo ""
            echo -e "${BLUE}Running local validation...${NC}"
            echo ""
            ./validate_config.sh --local "$@"
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
else
    echo -e "${GREEN}✓${NC} Services are running:"
    echo "$RUNNING" | sed 's/^/    /'
    echo ""
    
    # Run validation
    echo -e "${BLUE}Running validation...${NC}"
    echo ""
    ./validate_config.sh "$@"
fi
