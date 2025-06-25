#!/usr/bin/env bats

load test_helper

@test "SANDBOX_BASE_DIR defaults to HOME/Sandbox" {
    unset SANDBOX_BASE_DIR
    source "./config.sh"
    [ "$SANDBOX_BASE_DIR" = "$HOME/Sandbox" ]
}

@test "SANDBOX_BASE_DIR respects custom value" {
    export SANDBOX_BASE_DIR="/custom/path"
    source "./config.sh"
    [ "$SANDBOX_BASE_DIR" = "/custom/path" ]
}

@test "check_requirements fails on non-macOS" {
    # Mock command to simulate missing sandbox-exec
    function command() { return 1; }
    export -f command

    source "./config.sh"
    run check_requirements
    [ "$status" -eq 1 ]
    [ "${lines[0]}" = "❌ Error: sandbox-exec command not found" ]
}

@test "init_sandbox_dir creates directory if not exists" {
    SANDBOX_BASE_DIR="$BATS_TEST_TMPDIR/sandbox"
    source "./config.sh"
    run init_sandbox_dir
    [ -d "$SANDBOX_BASE_DIR" ]
}

@test "get_relative_path returns correct path" {
    SANDBOX_BASE_DIR="/test/sandbox"
    source "./config.sh"
    result=$(get_relative_path "/test/sandbox/project/file.txt")
    [ "$result" = "project/file.txt" ]
}
