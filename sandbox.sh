#!/bin/bash
# Usage: sandbox <command> [arguments]
# Examples:
#   sandbox npm start
#   sandbox yarn dev
#   sandbox node server.js

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || {
    echo "❌ Error: failed to determine script directory"
    exit 1
}

source "$SCRIPT_DIR/config.sh"

# Check dependencies
check_requirements

# Help function
show_help() {
    cat <<EOF
🔒 Sandbox - utility for secure command execution

USAGE:
    sandbox [options] <command> [arguments]

OPTIONS:
    -h, --help     Show this help

EXAMPLES:
    sandbox npm start          Run npm start
    sandbox yarn dev           Run yarn dev
    sandbox node server.js     Run node server.js

RESTRICTIONS:
    - Commands are executed only inside sandbox ($SANDBOX_BASE_DIR)
    - Network access is limited to necessary ports
    - File system access is restricted to sandbox
    - System calls are limited by security profile

CONFIGURATION:
    export SANDBOX_BASE_DIR="/path/to/sandbox"  # Default: $HOME/Sandbox

MORE INFO:
    Documentation: README.md in installation directory
EOF
    exit 0
}

# Check help flag
case "$1" in
-h | --help)
    show_help
    ;;
esac

# Combine all arguments into one command
COMMAND="$*"

if [ -z "$COMMAND" ]; then
    echo "❌ Please specify a command to run or -h for help"
    exit 1
fi

# Check profile existence
if [ ! -f "$SANDBOX_PROFILE" ]; then
    echo "❌ Error: sandbox.profile not found"
    echo "🔧 Please run setup first: ./sandbox-setup.sh"
    exit 1
fi

# Check if we are inside sandbox
if [[ "$PWD" != "$SANDBOX_BASE_DIR"* ]]; then
    echo "❌ Error: command must be executed inside $SANDBOX_BASE_DIR"
    exit 1
fi

# Get relative path for nice output
RELATIVE_PATH=$(get_relative_path "$PWD")

echo "🔒 Running command in sandbox: $COMMAND"
echo "📂 Working directory: $RELATIVE_PATH"

# Check Sandbox directory permissions
if [ "$(stat -f "%OLp" "$SANDBOX_BASE_DIR")" != "700" ]; then
    echo "⚠️  Warning: Sandbox directory permissions are not optimal"
    echo "🔧 Recommended: chmod 700 $SANDBOX_BASE_DIR"
fi

# Check for required utilities
if ! command -v sandbox-exec >/dev/null 2>&1; then
    echo "❌ Error: sandbox-exec utility not found"
    echo "⚠️  Make sure you are using macOS 10.15 or newer"
    exit 1
fi

# Run command in sandbox
sandbox-exec -f "$SANDBOX_PROFILE" "$@"

# Check return code
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ Command failed with error (code $EXIT_CODE)"
    exit $EXIT_CODE
fi
