#!/bin/bash

# Define script directory path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || {
    echo "❌ Error: failed to determine script directory"
    exit 1
}

# Load configuration
source "$SCRIPT_DIR/config.sh"

# Check dependencies
check_requirements

# Initialize sandbox directory
init_sandbox_dir

echo "🔧 Setting up sandbox in directory: $SANDBOX_BASE_DIR"

# Generate security profile
read_paths_str=$(printf "%s\n" "${SANDBOX_READ_PATHS[@]}" | paste -sd "," -)
generate_security_profile "$SANDBOX_PROFILE" "$SANDBOX_BASE_DIR" "$read_paths_str" "$HOME"

echo "✅ Security profile created: $SANDBOX_PROFILE"
echo "📝 Base sandbox directory: $SANDBOX_BASE_DIR"
echo ""
echo "🚀 To use, add to ~/.zshrc or ~/.bashrc:"
echo "alias sandbox=\"$SCRIPT_DIR/sandbox.sh\"  # Recommended"
echo "# Or add to PATH (alternative):"
echo "# export PATH=\"$SCRIPT_DIR:\$PATH\""
echo "export SANDBOX_BASE_DIR=\"$SANDBOX_BASE_DIR\"  # Optional, to change path"
