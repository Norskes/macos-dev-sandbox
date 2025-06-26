#!/usr/bin/env bash

# Load bats-support and bats-assert if installed
if [ -d "/usr/local/lib/bats-support" ]; then
    load '/usr/local/lib/bats-support/load.bash'
fi

if [ -d "/usr/local/lib/bats-assert" ]; then
    load '/usr/local/lib/bats-assert/load.bash'
fi

# Error handling
handle_error() {
    local err=$?
    local cmd=$BASH_COMMAND
    echo "Error in $1: command '$cmd' exited with status $err" >&2
    return $err
}

# Test environment setup
setup_common() {
    trap 'handle_error setup_common' ERR

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
    # Go up two levels from tests/integration to project root
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    # Copy only sandbox files
    cp "$PROJECT_ROOT"/*.sh "$TEST_SANDBOX_DIR/" || {
        echo "Failed to copy sandbox files to test directory" >&2
        return 1
    }

    # Export test directory for other tests
    export TEST_SANDBOX_DIR

    # Run setup in test environment
    (cd "$TEST_SANDBOX_DIR" && SANDBOX_BASE_DIR="$SANDBOX_BASE_DIR" ./sandbox-setup.sh) || {
        echo "Failed to run sandbox-setup.sh" >&2
        return 1
    }

    trap - ERR
}

# Cleanup after tests
teardown_common() {
    trap 'handle_error teardown_common' ERR

    # Restore original values
    export HOME="$ORIGINAL_HOME"
    export SANDBOX_BASE_DIR="$ORIGINAL_SANDBOX_BASE_DIR"

    # Remove temporary directory
    rm -rf "$BATS_TEST_TMPDIR"

    trap - ERR
}

# Load configuration in test environment
load_config() {
    trap 'handle_error load_config' ERR

    local test_dir="$1"

    # Verify test directory exists
    if [[ ! -d "$test_dir" ]]; then
        echo "Test directory '$test_dir' does not exist" >&2
        return 1
    fi

    # First load main config
    if [[ ! -f "$test_dir/config.sh" ]]; then
        echo "config.sh not found in '$test_dir'" >&2
        return 1
    fi
    source "$test_dir/config.sh"

    # Then load security settings
    if [[ ! -f "$test_dir/security.sh" ]]; then
        echo "security.sh not found in '$test_dir'" >&2
        return 1
    fi
    source "$test_dir/security.sh"

    trap - ERR
}
