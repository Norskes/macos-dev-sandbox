#!/usr/bin/env bash

# Load bats-support and bats-assert if installed
if [ -d "/usr/local/lib/bats-support" ]; then
    load '/usr/local/lib/bats-support/load.bash'
fi

if [ -d "/usr/local/lib/bats-assert" ]; then
    load '/usr/local/lib/bats-assert/load.bash'
fi

# Test environment setup
setup() {
    # Create temporary directory for tests
    export BATS_TEST_TMPDIR="$(mktemp -d)"

    # Save original values
    export ORIGINAL_HOME="$HOME"
    export ORIGINAL_SANDBOX_BASE_DIR="$SANDBOX_BASE_DIR"

    # Set up test environment
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
}

# Cleanup after tests
teardown() {
    # Restore original values
    export HOME="$ORIGINAL_HOME"
    export SANDBOX_BASE_DIR="$ORIGINAL_SANDBOX_BASE_DIR"

    # Remove temporary directory
    rm -rf "$BATS_TEST_TMPDIR"
}
