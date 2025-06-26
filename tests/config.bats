#!/usr/bin/env bats

load test_helper

setup() {
    trap 'handle_error setup' ERR
    setup_common
    trap - ERR
}

teardown() {
    trap 'handle_error teardown' ERR
    teardown_common
    trap - ERR
}

@test "SANDBOX_BASE_DIR defaults to HOME/Sandbox" {
    trap 'handle_error test_sandbox_base_dir_default' ERR

    # Сохраняем текущее значение для отладки
    local current_sandbox_dir="$SANDBOX_BASE_DIR"
    echo "Current SANDBOX_BASE_DIR before unset: $current_sandbox_dir" >&2

    unset SANDBOX_BASE_DIR
    load_config "$TEST_SANDBOX_DIR"

    # Проверяем значение после загрузки конфигурации
    echo "SANDBOX_BASE_DIR after load_config: $SANDBOX_BASE_DIR" >&2
    echo "HOME value: $HOME" >&2

    [ "$SANDBOX_BASE_DIR" = "$HOME/Sandbox" ]

    trap - ERR
}

@test "SANDBOX_BASE_DIR respects custom value" {
    export SANDBOX_BASE_DIR="/custom/path"
    load_config "$TEST_SANDBOX_DIR"
    [ "$SANDBOX_BASE_DIR" = "/custom/path" ]
}

@test "check_requirements fails on non-macOS" {
    trap 'handle_error test_check_requirements' ERR

    # Mock command to simulate missing sandbox-exec
    function command() { return 1; }
    export -f command

    load_config "$TEST_SANDBOX_DIR"
    run check_requirements
    [ "$status" -eq 1 ]
    [ "${lines[0]}" = "Error: sandbox-exec command not found" ]

    trap - ERR
}

@test "init_sandbox_dir creates directory if not exists" {
    SANDBOX_BASE_DIR="$BATS_TEST_TMPDIR/sandbox"
    load_config "$TEST_SANDBOX_DIR"
    run init_sandbox_dir
    [ -d "$SANDBOX_BASE_DIR" ]
}

@test "get_relative_path returns correct path" {
    SANDBOX_BASE_DIR="/test/sandbox"
    load_config "$TEST_SANDBOX_DIR"
    result=$(get_relative_path "/test/sandbox/project/file.txt")
    [ "$result" = "project/file.txt" ]
}

@test "security configuration is properly loaded" {
    load_config "$TEST_SANDBOX_DIR"
    [ ${#SANDBOX_CORE_BLOCKED_PATHS[@]} -gt 0 ]
    [ ${#SANDBOX_READ_PATHS[@]} -gt 0 ]
}
