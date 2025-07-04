#!/bin/bash

# Integration Test Runner - Full tests for local development
# Requires macOS and all dependencies (sandbox-exec, Docker, etc.)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Running Integration Tests (Full Suite)${NC}"
echo "=================================================="

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${YELLOW}⚠️  Integration tests require macOS${NC}"
    echo -e "${BLUE}💡 For CI tests (logic only), run: ./run_ci_tests.sh${NC}"
    exit 1
fi

# Check for sandbox-exec
if ! command -v sandbox-exec >/dev/null 2>&1; then
    echo -e "${RED}❌ sandbox-exec not found${NC}"
    echo -e "${YELLOW}Integration tests require macOS with sandbox-exec${NC}"
    echo -e "${BLUE}💡 For CI tests (logic only), run: ./run_ci_tests.sh${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$SCRIPT_DIR"

# Install bats if not available
if ! command -v bats >/dev/null 2>&1; then
    echo -e "${YELLOW}📦 Installing bats-core...${NC}"

    # Create local bin directory
    mkdir -p "$HOME/.local/bin"

    # Clone and install bats
    if [ ! -d "bats-core" ]; then
        git clone https://github.com/bats-core/bats-core.git
    fi

    cd bats-core
    ./install.sh "$HOME/.local"
    cd ..

    # Add to PATH for this session
    export PATH="$HOME/.local/bin:$PATH"
    echo -e "${GREEN}✅ Installed Bats to $HOME/.local/bin/bats${NC}"
fi

# Run integration tests
echo -e "${YELLOW}🧪 Running Integration Tests...${NC}"

# Count tests
total_tests=0
for test_file in integration/*.bats; do
    if [ -f "$test_file" ]; then
        test_count=$(grep -c "^@test" "$test_file" || echo 0)
        total_tests=$((total_tests + test_count))
    fi
done

echo "Found $total_tests integration tests to run"
echo ""

# Run each test file
exit_code=0
for test_file in integration/*.bats; do
    if [ -f "$test_file" ]; then
        echo -e "${YELLOW}Running $(basename "$test_file"):${NC}"
        if ! bats "$test_file"; then
            exit_code=1
        fi
        echo ""
    fi
done

if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✅ All integration tests passed!${NC}"
    echo -e "${GREEN}System is ready for production use${NC}"
else
    echo -e "${RED}❌ Some integration tests failed${NC}"
    echo -e "${RED}Fix issues before deployment${NC}"
fi

# Suggest running CI tests as well
echo ""
echo -e "${BLUE}💡 To run fast CI tests (for GitHub Actions): ./run_ci_tests.sh${NC}"

exit $exit_code
