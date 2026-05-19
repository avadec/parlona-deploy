#!/bin/bash
# Docker Configuration Validation Script

set -e

echo "======================================"
echo "Docker Configuration Validation"
echo "======================================"
echo ""

# Check if required files exist
echo "✓ Checking required files..."

required_files=(
    "parlona/pyproject.toml"
    "parlona/src/parlona/__init__.py"
    "parlona-server/requirements.txt"
    "parlona-server/Dockerfile.api"
    "parlona-server/Dockerfile.stt"
    "parlona-server/Dockerfile.summary"
    "parlona-server/Dockerfile.postprocess"
    "docker-compose.yml"
    ".dockerignore"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file NOT FOUND"
        exit 1
    fi
done

echo ""
echo "✓ Checking parlona package structure..."
if [ -d "parlona/src/parlona" ]; then
    echo "  ✓ parlona package structure is correct"
else
    echo "  ✗ parlona package structure is incorrect"
    exit 1
fi

echo ""
echo "✓ Checking parlona-server structure..."
required_dirs=(
    "parlona-server/server"
    "parlona-server/server/common"
    "parlona-server/server/repos"
    "parlona-server/server/workers"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir exists"
    else
        echo "  ✗ $dir NOT FOUND"
        exit 1
    fi
done

echo ""
echo "✓ Checking worker entry points..."
workers=(
    "parlona-server/server/workers/stt_worker.py"
    "parlona-server/server/workers/summary_worker.py"
    "parlona-server/server/workers/postprocess_worker.py"
)

for worker in "${workers[@]}"; do
    if grep -q "if __name__ == \"__main__\":" "$worker"; then
        echo "  ✓ $worker has __main__ entry point"
    else
        echo "  ✗ $worker missing __main__ entry point"
        exit 1
    fi
done

echo ""
echo "✓ Checking docker-compose.yml configuration..."

# Check if docker-compose.yml references the new Dockerfiles
if grep -q "parlona-server/Dockerfile.api" docker-compose.yml; then
    echo "  ✓ API service uses new Dockerfile"
else
    echo "  ✗ API service not updated"
    exit 1
fi

if grep -q "parlona-server/Dockerfile.stt" docker-compose.yml; then
    echo "  ✓ STT service uses new Dockerfile"
else
    echo "  ✗ STT service not updated"
    exit 1
fi

if grep -q "parlona-server/Dockerfile.summary" docker-compose.yml; then
    echo "  ✓ Summary service uses new Dockerfile"
else
    echo "  ✗ Summary service not updated"
    exit 1
fi

if grep -q "parlona-server/Dockerfile.postprocess" docker-compose.yml; then
    echo "  ✓ Postprocess service uses new Dockerfile"
else
    echo "  ✗ Postprocess service not updated"
    exit 1
fi

echo ""
echo "✓ Checking environment variables..."
if [ -f ".env" ]; then
    echo "  ✓ .env file exists"
    
    # Check for critical environment variables
    required_vars=(
        "REDIS_PASSWORD"
        "POSTGRES_PASSWORD"
        "CALL_API_KEY"
    )
    
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" .env; then
            echo "  ✓ $var is set in .env"
        else
            echo "  ⚠ $var not found in .env (may need to be added)"
        fi
    done
else
    echo "  ⚠ .env file not found (you may need to create one)"
fi

echo ""
echo "======================================"
echo "✓ All validation checks passed!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Ensure .env file has all required variables"
echo "  2. Build the services: docker compose build"
echo "  3. Start the stack: docker compose up -d"
echo "  4. Check logs: docker compose logs -f"
echo ""
