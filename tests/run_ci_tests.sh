#!/bin/bash

# CI Test Runner - Fast tests for GitHub Actions
# Only runs logic tests without external dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 Running CI Tests (Logic Only)${NC}"
echo "=================================================="

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

# Run CI tests only
echo -e "${YELLOW}🧪 Running CI Tests...${NC}"

# Count tests
total_tests=0
for test_file in ci/*.bats; do
    if [ -f "$test_file" ]; then
        test_count=$(grep -c "^@test" "$test_file" || echo 0)
        total_tests=$((total_tests + test_count))
    fi
done

echo "Found $total_tests CI tests to run"
echo ""

# Run each test file
exit_code=0
for test_file in ci/*.bats; do
    if [ -f "$test_file" ]; then
        echo -e "${YELLOW}Running $(basename "$test_file"):${NC}"
        if ! bats "$test_file"; then
            exit_code=1
        fi
        echo ""
    fi
done

if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✅ All CI tests passed!${NC}"
    echo -e "${GREEN}Ready for GitHub Actions${NC}"
else
    echo -e "${RED}❌ Some CI tests failed${NC}"
    echo -e "${RED}Fix issues before pushing${NC}"
fi

exit $exit_code
