#!/usr/bin/env bats

load test_helper

# Load functions for testing
setup() {
    # Load common functions - go up two levels to project root
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    source "$PROJECT_ROOT/sandbox-docker.sh"

    # Mock docker command
    function docker() {
        echo "DOCKER_MOCK: $*"
        return 0
    }
    export -f docker

    # Mock git command
    function git() {
        echo "GIT_MOCK: $*"
        return 0
    }
    export -f git

    # Mock lsof
    function lsof() {
        return 1
    }
    export -f lsof

    # Mock cd
    function cd() {
        return 0
    }
    export -f cd

    # Mock mkdir
    function mkdir() {
        return 0
    }
    export -f mkdir
}

@test "help flag shows usage information" {
    run main --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Docker Sandbox - secure repository execution in Docker"
    echo "$output" | grep -q "sandbox-docker <git-url>"
}

@test "no arguments shows error" {
    run main
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Please specify repository URL"
}

@test "get_available_container_name returns base name if no conflicts" {
    # Mock docker ps for empty output
    function docker() {
        if [[ "$*" == *"ps"* ]]; then
            return 0
        fi
    }
    export -f docker

    result=$(get_available_container_name "test-container")
    [ "$result" = "test-container" ]
}

@test "get_available_container_name increments if conflict exists" {
    # Mock docker ps for existing container
    function docker() {
        if [[ "$*" == *"ps"* ]]; then
            echo "test-container"
        fi
    }
    export -f docker

    result=$(get_available_container_name "test-container")
    [ "$result" = "test-container-1" ]
}

@test "is_port_available returns true for free port" {
    # Mock lsof for free port
    function lsof() { return 1; }
    export -f lsof

    run is_port_available 3000
    [ "$status" -eq 0 ]
}

@test "is_port_available returns false for used port" {
    # Mock lsof for used port
    function lsof() { return 0; }
    export -f lsof

    run is_port_available 3000
    [ "$status" -eq 1 ]
}

@test "get_available_port returns next available port" {
    # Mock is_port_available
    function is_port_available() {
        [[ "$1" -eq 3001 ]]
    }
    export -f is_port_available

    result=$(get_available_port 3000)
    [ "$result" -eq 3001 ]
}

@test "get_available_port skips excluded ports" {
    # Mock is_port_available
    function is_port_available() {
        return 0
    }
    export -f is_port_available

    result=$(get_available_port 3000 3000 3001)
    [ "$result" -eq 3002 ]
}

@test "docker run uses correct parameters" {
    run main "git@github.com:test/repo.git"
    echo "$output" | grep -q "DOCKER_MOCK: run -it --rm"
    echo "$output" | grep -q "\-\-cap-drop=ALL"
    echo "$output" | grep -q "\-\-security-opt=no-new-privileges"
    echo "$output" | grep -q "\-\-memory=2g"
    echo "$output" | grep -q "\-\-cpus=2"
    echo "$output" | grep -q "node:20-slim"
}

@test "custom ports are properly handled" {
    run main "git@github.com:test/repo.git" --ports 8080,9000
    echo "$output" | grep -q "8080"
    echo "$output" | grep -q "9000"
    [ ! "$(echo "$output" | grep -c "3000")" -gt 0 ]
}

@test "custom hosts are properly handled" {
    run main "git@github.com:test/repo.git" --hosts test.local,dev.local
    echo "$output" | grep -q "test.local"
    echo "$output" | grep -q "dev.local"
    echo "$output" | grep -q "\-\-add-host"
}

@test "localhost and 127.0.0.1 are not added as extra hosts" {
    run main "git@github.com:test/repo.git" --hosts localhost,127.0.0.1
    [ ! "$(echo "$output" | grep -c "add-host=localhost")" -gt 0 ]
    [ ! "$(echo "$output" | grep -c "add-host=127.0.0.1")" -gt 0 ]
}

@test "repository is cloned if not exists" {
    # Mock test for directory existence check
    function test() { return 1; }
    export -f test

    run main "git@github.com:test/repo.git"
    echo "$output" | grep -q "GIT_MOCK: clone"
}
