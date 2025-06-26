#!/bin/bash

# Error handling
handle_error() {
    local err=$?
    local cmd=$BASH_COMMAND
    echo "Error in config.sh: command '$cmd' exited with status $err" >&2
    return $err
}

trap 'handle_error' ERR

# Define script directory path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || {
    echo "Error: failed to determine script directory" >&2
    exit 1
}

# Load security settings only if not already loaded
if [[ -z "$SANDBOX_CORE_BLOCKED_PATHS" ]]; then
    source "$SCRIPT_DIR/security.sh"
fi

# Define the base sandbox directory
# By default - user's home directory + /Sandbox
if [ -z "$SANDBOX_BASE_DIR" ]; then
    if [ -z "$HOME" ]; then
        echo "Error: HOME environment variable is not set" >&2
        exit 1
    fi
    export SANDBOX_BASE_DIR="$HOME/Sandbox"
fi

# Path to security profile
export SANDBOX_PROFILE="$SANDBOX_BASE_DIR/sandbox.profile"

# Additional paths to block (extends core blocked paths from security.sh)
export SANDBOX_BLOCKED_PATHS=(
    # Add your custom paths here
    # Example:
    # "$HOME/Projects"     # Personal projects
    # "$HOME/Work"         # Work files
)

# Docker configuration (used by sandbox-docker.sh)
export DOCKER_DEFAULT_PORTS=(3000 3001 5000 5173 8000 8080 8081 9000 4200 1337)
export DOCKER_DEFAULT_HOSTS=("localhost" "127.0.0.1" "0.0.0.0" "host.docker.internal")
export DOCKER_CONTAINER_PREFIX="nrsk-sandbox"
export DOCKER_DEFAULT_IMAGE="node:20-slim"

# Resource limits
export DOCKER_MEMORY_LIMIT="2g"
export DOCKER_CPU_LIMIT="2"
export DOCKER_PIDS_LIMIT="100"
export DOCKER_FILES_LIMIT="1024"

# Check for required commands
check_requirements() {
    if ! command -v sandbox-exec >/dev/null 2>&1; then
        echo "Error: sandbox-exec command not found" >&2
        echo "This utility only works on macOS" >&2
        exit 1
    fi
}

# Check and create sandbox directory
init_sandbox_dir() {
    if [ ! -d "$SANDBOX_BASE_DIR" ]; then
        echo "Creating sandbox directory: $SANDBOX_BASE_DIR" >&2
        mkdir -p "$SANDBOX_BASE_DIR"
    fi
}

# Get relative path from base directory
get_relative_path() {
    local path="$1"
    # Remove trailing slash from path
    path="${path%/}"

    if [ "$path" = "$SANDBOX_BASE_DIR" ]; then
        echo "."
    else
        echo "${path#"$SANDBOX_BASE_DIR"/}"
    fi
}

# Export functions and variables
export -f check_requirements
export -f init_sandbox_dir
export -f get_relative_path

trap - ERR
