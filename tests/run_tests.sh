#!/bin/bash

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

# Function to run tests
run_tests() {
    local test_files=("$@")
    if [ ${#test_files[@]} -eq 0 ]; then
        # If no files specified, run all tests except post-install
        test_files=($(find "$SCRIPT_DIR" -name "*.bats" ! -name "post-install.bats"))
    fi
    bats "${test_files[@]}"
}

# Check arguments
case "$1" in
--post-install)
    # Check requirements for post-install tests
    if [ -z "$SANDBOX_BASE_DIR" ]; then
        echo "❌ Error: SANDBOX_BASE_DIR not set"
        echo "Post-install tests require sandbox to be installed and configured"
        exit 1
    fi

    if [ ! -f "$SANDBOX_BASE_DIR/sandbox.profile" ]; then
        echo "❌ Error: sandbox.profile not found"
        echo "Post-install tests require sandbox to be installed and configured"
        exit 1
    fi

    if ! command -v sandbox >/dev/null 2>&1; then
        echo "❌ Error: sandbox command not found"
        echo "Post-install tests require sandbox to be installed and in PATH"
        exit 1
    fi

    echo "Running post-install tests..."
    run_tests "$SCRIPT_DIR/post-install.bats"
    ;;
*)
    # Run regular tests
    run_tests "$@"
    ;;
esac
