#!/bin/bash

# Define the base sandbox directory
# By default - user's home directory + /Sandbox
if [ -z "$SANDBOX_BASE_DIR" ]; then
    export SANDBOX_BASE_DIR="$HOME/Sandbox"
fi

# Path to security profile
export SANDBOX_PROFILE="$SANDBOX_BASE_DIR/sandbox.profile"

# Check for required commands
check_requirements() {
    if ! command -v sandbox-exec >/dev/null 2>&1; then
        echo "❌ Error: sandbox-exec command not found"
        echo "⚠️ This utility only works on macOS"
        exit 1
    fi
}

# Check and create sandbox directory
init_sandbox_dir() {
    if [ ! -d "$SANDBOX_BASE_DIR" ]; then
        echo "📂 Creating sandbox directory: $SANDBOX_BASE_DIR"
        mkdir -p "$SANDBOX_BASE_DIR"
    fi
}

# Get relative path from base directory
get_relative_path() {
    local path="$1"
    echo "${path#"$SANDBOX_BASE_DIR"/}"
}
