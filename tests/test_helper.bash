#!/usr/bin/env bash

# Load bats-support and bats-assert if installed
if [ -d "/usr/local/lib/bats-support" ]; then
    load '/usr/local/lib/bats-support/load.bash'
fi

if [ -d "/usr/local/lib/bats-assert" ]; then
    load '/usr/local/lib/bats-assert/load.bash'
fi

# Test environment setup
setup_common() {
    # Create temporary directory for tests
    export BATS_TEST_TMPDIR="$(mktemp -d)"

    # Save original values
    export ORIGINAL_HOME="$HOME"
    export ORIGINAL_SANDBOX_BASE_DIR="$SANDBOX_BASE_DIR"

    # Set up test environment
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"

    # Set up sandbox environment
    export SANDBOX_BASE_DIR="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$SANDBOX_BASE_DIR"
    chmod 700 "$SANDBOX_BASE_DIR"

    # Copy sandbox files to test directory
    TEST_SANDBOX_DIR="$BATS_TEST_TMPDIR/sandbox-test"
    mkdir -p "$TEST_SANDBOX_DIR"
    cp -r "$(cd .. && pwd)"/* "$TEST_SANDBOX_DIR/"

    # Run setup in test environment
    (cd "$TEST_SANDBOX_DIR" && SANDBOX_BASE_DIR="$SANDBOX_BASE_DIR" ./sandbox-setup.sh >/dev/null)
}

# Cleanup after tests
teardown_common() {
    # Restore original values
    export HOME="$ORIGINAL_HOME"
    export SANDBOX_BASE_DIR="$ORIGINAL_SANDBOX_BASE_DIR"

    # Remove temporary directory
    rm -rf "$BATS_TEST_TMPDIR"
}
