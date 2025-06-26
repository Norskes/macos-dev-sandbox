#!/bin/bash

# Define script directory path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || {
    echo "❌ Error: failed to determine script directory"
    exit 1
}

# Load configuration
source "$SCRIPT_DIR/config.sh"

# Function to confirm action
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    while true; do
        read -r -p "$prompt [y/N] " response
        response=${response:-$default}
        case $response in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to remove line from file if it exists
remove_line_from_file() {
    local file="$1"
    local pattern="$2"

    if [ -f "$file" ]; then
        sed -i '' "\#$pattern#d" "$file" 2>/dev/null || true
    fi
}

echo "🔄 Starting sandbox uninstallation..."

# Remove sandbox profile
if [ -f "$SANDBOX_PROFILE" ]; then
    rm -f "$SANDBOX_PROFILE"
    echo "✅ Removed sandbox profile: $SANDBOX_PROFILE"
else
    echo "ℹ️  Sandbox profile not found: $SANDBOX_PROFILE"
fi

# Remove symlink
if [ -L "$SCRIPT_DIR/sandbox" ]; then
    rm -f "$SCRIPT_DIR/sandbox"
    echo "✅ Removed sandbox symlink"
else
    echo "ℹ️  Sandbox symlink not found"
fi

# Show instructions for cleaning up shell configuration
echo "
📝 To complete uninstallation, remove these lines from your ~/.zshrc or ~/.bashrc:
    export PATH=\"$SCRIPT_DIR:\$PATH\"
    export SANDBOX_BASE_DIR=\"$SANDBOX_BASE_DIR\"
"

# Optionally remove sandbox directory
if [ -d "$SANDBOX_BASE_DIR" ]; then
    if confirm "❓ Do you want to remove the sandbox directory ($SANDBOX_BASE_DIR)?"; then
        rm -rf "$SANDBOX_BASE_DIR"
        echo "✅ Removed sandbox directory: $SANDBOX_BASE_DIR"
    else
        echo "ℹ️  Keeping sandbox directory: $SANDBOX_BASE_DIR"
    fi
fi

echo "
✨ Uninstallation complete!

Note: You may need to restart your shell or run 'source ~/.zshrc' (or ~/.bashrc)
      after removing the configuration lines."
