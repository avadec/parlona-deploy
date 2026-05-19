#!/bin/bash
#
# VoiceCore Configuration Validator
# 
# Quick validation script for customers to test their configuration.
# Tests both STT (Speech-to-Text) and LLM backend setup.
#
# Usage:
#   ./validate_config.sh [OPTIONS]
#
# Options:
#   --stt              Test STT configuration only
#   --llm              Test LLM configuration only
#   --stt-audio FILE   Test STT with specific audio file
#   --llm-backend NAME Test LLM with specific backend (openai|vllm|groq|ollama)
#   --llm-transcript   Run full LLM summarization test
#   --all              Test both STT and LLM (default)
#   --local            Run validation locally (requires venv with dependencies)
#   --help             Show this help message
#
# Examples:
#   ./validate_config.sh                          # Test everything via Docker
#   ./validate_config.sh --stt                    # Test STT only via Docker
#   ./validate_config.sh --llm                    # Test LLM only via Docker
#   ./validate_config.sh --stt --stt-audio test.wav  # Test STT with audio via Docker
#   ./validate_config.sh --llm --llm-transcript   # Test LLM with summarization via Docker
#   ./validate_config.sh --local --stt            # Test STT locally (with venv)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
TEST_STT=false
TEST_LLM=false
STT_AUDIO=""
LLM_BACKEND=""
LLM_TRANSCRIPT=false
RUN_LOCAL=false

show_help() {
    echo -e "${BLUE}VoiceCore Configuration Validator${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --stt              Test STT configuration only"
    echo "  --llm              Test LLM configuration only"
    echo "  --stt-audio FILE   Test STT with specific audio file"
    echo "  --llm-backend NAME Test LLM with specific backend (openai|vllm|groq|ollama)"
    echo "  --llm-transcript   Run full LLM summarization test"
    echo "  --all              Test both STT and LLM (default)"
    echo "  --local            Run validation locally (requires venv with dependencies)"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Test everything via Docker"
    echo "  $0 --stt                              # Test STT only via Docker"
    echo "  $0 --llm                              # Test LLM only via Docker"
    echo "  $0 --stt --stt-audio test.wav         # Test STT with audio via Docker"
    echo "  $0 --llm --llm-transcript             # Test LLM with summarization via Docker"
    echo "  $0 --local --stt                      # Test STT locally (with venv)"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --stt)
            TEST_STT=true
            shift
            ;;
        --llm)
            TEST_LLM=true
            shift
            ;;
        --stt-audio)
            STT_AUDIO="$2"
            shift 2
            ;;
        --llm-backend)
            LLM_BACKEND="$2"
            shift 2
            ;;
        --llm-transcript)
            LLM_TRANSCRIPT=true
            shift
            ;;
        --all)
            TEST_STT=true
            TEST_LLM=true
            shift
            ;;
        --local)
            RUN_LOCAL=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# If neither specified, test both
if [ "$TEST_STT" = false ] && [ "$TEST_LLM" = false ]; then
    TEST_STT=true
    TEST_LLM=true
fi

echo -e "${BLUE}"
echo "============================================================"
echo "  VoiceCore Configuration Validator"
echo "============================================================"
echo -e "${NC}"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if Docker is running (for Docker mode)
if [ "$RUN_LOCAL" = false ]; then
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Docker is not running. Please start Docker first."
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo "  1. Start Docker Desktop or docker service"
        echo "  2. Use --local flag to run validation locally (requires venv)"
        echo ""
        exit 1
    fi
    
    # Check if any VoiceCore containers are running
    RUNNING_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '(stt_service|summary_service|call_analytics_api)' || true)
    
    if [ -z "$RUNNING_CONTAINERS" ]; then
        echo -e "${YELLOW}⚠${NC} No VoiceCore services are running"
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo "  1. Start your services: docker compose up -d"
        echo "  2. Use --local flag to run validation locally (requires venv)"
        echo ""
        echo -e "${BLUE}Tip:${NC} Validation runs inside Docker containers by default."
        echo "      You need running containers to validate your configuration."
        echo ""
        exit 1
    else
        echo -e "${GREEN}✓${NC} Found running VoiceCore services"
        echo ""
    fi
fi

# Check if .env file exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${GREEN}✓${NC} Loading configuration from .env file"
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
else
    echo -e "${YELLOW}⚠${NC} No .env file found, using environment variables"
fi

EXIT_CODE=0

# Test STT
if [ "$TEST_STT" = true ]; then
    echo -e "${BLUE}------------------------------------------------------------"
    echo "  Testing STT Configuration"
    echo -e "------------------------------------------------------------${NC}"
    echo ""
    
    if [ "$RUN_LOCAL" = true ]; then
        # Run locally (requires venv)
        echo -e "${YELLOW}Running STT validation locally...${NC}"
        STT_CMD="python3 $SCRIPT_DIR/validate_stt.py"
        if [ -n "$STT_AUDIO" ]; then
            STT_CMD="$STT_CMD --audio-path $STT_AUDIO"
        fi
        
        if $STT_CMD; then
            echo -e "${GREEN}✓${NC} STT validation completed successfully"
        else
            echo -e "${RED}✗${NC} STT validation failed"
            EXIT_CODE=1
        fi
    else
        # Run via Docker (default)
        echo -e "${YELLOW}Running STT validation via Docker...${NC}"
        
        # Check if Docker is running
        if ! docker info >/dev/null 2>&1; then
            echo -e "${RED}✗${NC} Docker is not running. Please start Docker first."
            echo -e "${YELLOW}  Or use --local to run validation locally (requires venv)${NC}"
            EXIT_CODE=1
        else
            # Build STT validation command for Docker
            STT_CMD="python3 /app/validate_stt.py"
            if [ -n "$STT_AUDIO" ]; then
                # Copy audio file to container if specified
                AUDIO_BASENAME=$(basename "$STT_AUDIO")
                docker cp "$STT_AUDIO" voicecore-stt_service-1:/tmp/test_audio.wav 2>/dev/null || \
                docker cp "$STT_AUDIO" voicecore_stt_service_1:/tmp/test_audio.wav 2>/dev/null || \
                docker cp "$STT_AUDIO" stt_service:/tmp/test_audio.wav 2>/dev/null || {
                    echo -e "${YELLOW}⚠${NC} Could not copy audio file. Testing without audio."
                    STT_AUDIO=""
                }
                STT_CMD="$STT_CMD --audio-path /tmp/test_audio.wav"
            fi
            
            # Try common container names
            CONTAINER_NAMES=("voicecore-stt_service-1" "voicecore_stt_service_1" "stt_service")
            CONTAINER_FOUND=""
            
            for CONTAINER in "${CONTAINER_NAMES[@]}"; do
                if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
                    CONTAINER_FOUND="$CONTAINER"
                    break
                fi
            done
            
            # If still not found, try fuzzy matching
            if [ -z "$CONTAINER_FOUND" ]; then
                CONTAINER_FOUND=$(docker ps --format '{{.Names}}' | grep -i 'stt' | head -n1)
            fi
            
            if [ -n "$CONTAINER_FOUND" ]; then
                echo -e "${GREEN}✓${NC} Found STT container: $CONTAINER_FOUND"
                
                # Copy container-specific validation script
                docker cp "$SCRIPT_DIR/validate_stt_container.py" "$CONTAINER_FOUND:/app/validate_stt.py" >/dev/null 2>&1
                
                # Run validation inside container
                if docker exec "$CONTAINER_FOUND" python3 /app/validate_stt.py; then
                    echo -e "${GREEN}✓${NC} STT validation completed successfully"
                else
                    echo -e "${RED}✗${NC} STT validation failed"
                    EXIT_CODE=1
                fi
            else
                echo -e "${RED}✗${NC} STT service container not found"
                echo -e "${YELLOW}  Is the stack running? Try: docker compose ps${NC}"
                echo -e "${YELLOW}  Or use --local to run validation locally${NC}"
                EXIT_CODE=1
            fi
        fi
    fi
    echo ""
fi

# Test LLM
if [ "$TEST_LLM" = true ]; then
    echo -e "${BLUE}------------------------------------------------------------"
    echo "  Testing LLM Configuration"
    echo -e "------------------------------------------------------------${NC}"
    echo ""
    
    if [ "$RUN_LOCAL" = true ]; then
        # Run locally (requires venv)
        echo -e "${YELLOW}Running LLM validation locally...${NC}"
        LLM_CMD="python3 $SCRIPT_DIR/validate_llm.py"
        if [ -n "$LLM_BACKEND" ]; then
            LLM_CMD="$LLM_CMD --backend $LLM_BACKEND"
        fi
        if [ "$LLM_TRANSCRIPT" = true ]; then
            LLM_CMD="$LLM_CMD --test-transcript"
        fi
        
        if $LLM_CMD; then
            echo -e "${GREEN}✓${NC} LLM validation completed successfully"
        else
            echo -e "${RED}✗${NC} LLM validation failed"
            EXIT_CODE=1
        fi
    else
        # Run via Docker (default)
        echo -e "${YELLOW}Running LLM validation via Docker...${NC}"
        
        # Check if Docker is running
        if ! docker info >/dev/null 2>&1; then
            echo -e "${RED}✗${NC} Docker is not running. Please start Docker first."
            echo -e "${YELLOW}  Or use --local to run validation locally (requires venv)${NC}"
            EXIT_CODE=1
        else
            # Build LLM validation command for Docker
            LLM_CMD="python3 /app/validate_llm.py"
            if [ -n "$LLM_BACKEND" ]; then
                LLM_CMD="$LLM_CMD --backend $LLM_BACKEND"
            fi
            if [ "$LLM_TRANSCRIPT" = true ]; then
                LLM_CMD="$LLM_CMD --test-transcript"
            fi
            
            # Try common container names (summary_service has LLM client)
            CONTAINER_NAMES=("voicecore-summary_service-1" "voicecore_summary_service_1" "summary_service" \
                           "voicecore-call_analytics_api-1" "voicecore_call_analytics_api_1" "call_analytics_api")
            CONTAINER_FOUND=""
            
            for CONTAINER in "${CONTAINER_NAMES[@]}"; do
                if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
                    CONTAINER_FOUND="$CONTAINER"
                    break
                fi
            done
            
            # If still not found, try fuzzy matching
            if [ -z "$CONTAINER_FOUND" ]; then
                CONTAINER_FOUND=$(docker ps --format '{{.Names}}' | grep -iE '(summary|analytics)' | head -n1)
            fi
            
            if [ -n "$CONTAINER_FOUND" ]; then
                echo -e "${GREEN}✓${NC} Found LLM container: $CONTAINER_FOUND"
                
                # Copy container-specific validation script
                docker cp "$SCRIPT_DIR/validate_llm_container.py" "$CONTAINER_FOUND:/app/validate_llm.py" >/dev/null 2>&1
                
                # Run validation inside container
                if docker exec "$CONTAINER_FOUND" python3 /app/validate_llm.py; then
                    echo -e "${GREEN}✓${NC} LLM validation completed successfully"
                else
                    echo -e "${RED}✗${NC} LLM validation failed"
                    EXIT_CODE=1
                fi
            else
                echo -e "${RED}✗${NC} Service container not found"
                echo -e "${YELLOW}  Is the stack running? Try: docker compose ps${NC}"
                echo -e "${YELLOW}  Or use --local to run validation locally${NC}"
                EXIT_CODE=1
            fi
        fi
    fi
    echo ""
fi

# Final summary
echo -e "${BLUE}============================================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}  ✅ ALL VALIDATIONS PASSED${NC}"
    echo ""
    echo "  Your VoiceCore configuration is ready for deployment."
else
    echo -e "${RED}  ⚠️  VALIDATION FAILED${NC}"
    echo ""
    echo "  Please review the errors above and fix your configuration."
fi
echo -e "${BLUE}============================================================${NC}"
echo ""

exit $EXIT_CODE
