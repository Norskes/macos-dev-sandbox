#!/usr/bin/env bats

# CI Tests - Fast logic tests without external dependencies

setup() {
    # Create temporary test environment
    export BATS_TEST_TMPDIR="$(mktemp -d)"
    export TEST_HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$TEST_HOME"

    # Get actual test directory location
    REAL_TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$REAL_TEST_DIR/../.." && pwd)"

    # Copy config files for testing
    TEST_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
    mkdir -p "$TEST_CONFIG_DIR"
    cp "$PROJECT_ROOT/config.sh" "$TEST_CONFIG_DIR/"
    cp "$PROJECT_ROOT/security.sh" "$TEST_CONFIG_DIR/"

    export TEST_CONFIG_DIR
}

teardown() {
    rm -rf "$BATS_TEST_TMPDIR"
}

@test "config.sh sets default SANDBOX_BASE_DIR correctly" {
    cd "$TEST_CONFIG_DIR"

    # Test with unset SANDBOX_BASE_DIR
    unset SANDBOX_BASE_DIR
    HOME="$TEST_HOME" source config.sh

    [ "$SANDBOX_BASE_DIR" = "$TEST_HOME/Sandbox" ]
}

@test "config.sh respects existing SANDBOX_BASE_DIR" {
    cd "$TEST_CONFIG_DIR"

    export SANDBOX_BASE_DIR="/custom/sandbox/path"
    HOME="$TEST_HOME" source config.sh

    [ "$SANDBOX_BASE_DIR" = "/custom/sandbox/path" ]
}

@test "Docker configuration variables are exported" {
    cd "$TEST_CONFIG_DIR"
    source config.sh

    # Check key Docker variables are set
    [ -n "$DOCKER_DEFAULT_IMAGE" ]
    [ -n "$DOCKER_MEMORY_LIMIT" ]
    [ -n "$DOCKER_CPU_LIMIT" ]
    [ -n "$DOCKER_CONTAINER_PREFIX" ]

    # Check arrays are defined
    [ ${#DOCKER_DEFAULT_PORTS[@]} -gt 0 ]
    [ ${#DOCKER_DEFAULT_HOSTS[@]} -gt 0 ]
}

@test "get_relative_path function works correctly" {
    cd "$TEST_CONFIG_DIR"
    source config.sh

    # Test basic relative path
    SANDBOX_BASE_DIR="/home/user/sandbox"
    result=$(get_relative_path "/home/user/sandbox/project/file.txt")
    [ "$result" = "project/file.txt" ]

    # Test root path
    result=$(get_relative_path "/home/user/sandbox")
    [ "$result" = "." ]

    # Test with trailing slash
    result=$(get_relative_path "/home/user/sandbox/")
    [ "$result" = "." ]
}

@test "security.sh defines required arrays" {
    cd "$TEST_CONFIG_DIR"
    source config.sh
    source security.sh

    # Check critical arrays are defined
    [ ${#SANDBOX_CORE_BLOCKED_PATHS[@]} -gt 0 ]
    [ ${#SANDBOX_READ_PATHS[@]} -gt 0 ]

    # Check specific critical paths are in blocked list
    local found_ssh=false
    local found_aws=false
    for path in "${SANDBOX_CORE_BLOCKED_PATHS[@]}"; do
        if [[ "$path" == *".ssh"* ]]; then found_ssh=true; fi
        if [[ "$path" == *".aws"* ]]; then found_aws=true; fi
    done
    [ "$found_ssh" = true ]
    [ "$found_aws" = true ]
}

@test "check_requirements detects missing commands" {
    cd "$TEST_CONFIG_DIR"
    source config.sh

    # Mock command to always fail
    command() { return 1; }
    export -f command

    run check_requirements
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "command not found"
}
