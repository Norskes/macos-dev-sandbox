#!/usr/bin/env bash

# Define script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || {
    echo "❌ Error: failed to determine script directory"
    exit 1
}

# Change to project root directory
cd "$SCRIPT_DIR/.." || exit 1

# Check for bats
if ! command -v bats &>/dev/null; then
    echo "Installing bats-core..."
    mkdir -p "$HOME/.local/bin"
    git clone https://github.com/bats-core/bats-core.git
    cd bats-core || exit 1
    ./install.sh "$HOME/.local"
    cd .. || exit 1
    rm -rf bats-core
    export PATH="$HOME/.local/bin:$PATH"
fi

# Run all test files
bats "$SCRIPT_DIR"/*.bats
