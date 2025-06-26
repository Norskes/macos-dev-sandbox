#!/usr/bin/env bats

# CI Tests - Docker logic tests without actual Docker execution

setup() {
    # Load Docker functions for testing
    export BATS_TEST_TMPDIR="$(mktemp -d)"

    # Get actual test directory location
    REAL_TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$REAL_TEST_DIR/../.." && pwd)"

    # Copy and source sandbox-docker.sh
    cp "$PROJECT_ROOT/sandbox-docker.sh" "$BATS_TEST_TMPDIR/"
    cp "$PROJECT_ROOT/config.sh" "$BATS_TEST_TMPDIR/"
    cp "$PROJECT_ROOT/security.sh" "$BATS_TEST_TMPDIR/"

    cd "$BATS_TEST_TMPDIR"
    source config.sh
    source sandbox-docker.sh

    # Mock external dependencies
    function docker() {
        echo "DOCKER_MOCK: $*"
        return 0
    }
    function git() {
        echo "GIT_MOCK: $*"
        return 0
    }
    function lsof() { return 1; } # Simulate free ports
    function mkdir() { return 0; }
    function cd() { return 0; }
    export -f docker git lsof mkdir cd
}

teardown() {
    rm -rf "$BATS_TEST_TMPDIR"
}

@test "get_available_container_name returns base name when no conflicts" {
    # Mock docker ps to return empty (no existing containers)
    function docker() {
        if [[ "$*" == *"ps"* ]]; then
            echo ""
        fi
        return 0
    }
    export -f docker

    result=$(get_available_container_name "test-container")
    [ "$result" = "test-container" ]
}

@test "get_available_container_name increments when conflicts exist" {
    # Mock docker ps to return existing container
    function docker() {
        if [[ "$*" == *"ps"* ]]; then
            echo "test-container"
        fi
        return 0
    }
    export -f docker

    result=$(get_available_container_name "test-container")
    [ "$result" = "test-container-1" ]
}

@test "is_port_available detects free ports" {
    function lsof() { return 1; } # Port is free
    export -f lsof

    run is_port_available 3000
    [ "$status" -eq 0 ]
}

@test "is_port_available detects used ports" {
    function lsof() { return 0; } # Port is used
    export -f lsof

    run is_port_available 3000
    [ "$status" -eq 1 ]
}

@test "get_available_port finds next available port" {
    # Mock port 3000 as used, 3001 as free
    function is_port_available() {
        [[ "$1" != "3000" ]]
    }
    export -f is_port_available

    result=$(get_available_port 3000)
    [ "$result" -eq 3001 ]
}

@test "get_available_port skips excluded ports correctly" {
    function is_port_available() { return 0; } # All ports free
    export -f is_port_available

    # Should skip 3000, 3001 and return 3002
    result=$(get_available_port 3000 3000 3001)
    [ "$result" -eq 3002 ]
}

@test "check_path_safety validates sandbox paths" {
    SANDBOX_BASE_DIR="/test/sandbox"

    # Test valid path
    run check_path_safety "/test/sandbox/project"
    [ "$status" -eq 0 ]

    # Test invalid path (outside sandbox)
    run check_path_safety "/etc/passwd"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "must be inside sandbox"
}

@test "show_help displays usage information" {
    run show_help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Docker Sandbox"
    echo "$output" | grep -q "sandbox-docker <git-url>"
    echo "$output" | grep -q "Examples:"
}
