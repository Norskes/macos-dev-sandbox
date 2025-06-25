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

# Create security profile
cat >"$SANDBOX_PROFILE" <<EOF
(version 1)
(allow default)

;; Allow reading everywhere (needed for npm/yarn/pnpm)
(allow file-read*)

;; Allow writing only in specific directories
(allow file-write*
    (subpath "$SANDBOX_BASE_DIR")           ;; Sandbox directory
    (subpath "/private/var/folders")        ;; macOS temporary files
    (subpath "/private/tmp")                ;; Temporary files
    (subpath "$HOME/Library/Caches")        ;; Cache
    (subpath "$HOME/Library/Logs")          ;; Logs
    (subpath "$HOME/.npm")                  ;; npm cache
    (subpath "$HOME/.yarn")                 ;; yarn cache
    (subpath "$HOME/.pnpm-store")           ;; pnpm cache
    (subpath "$HOME/.cache")                ;; Common cache
)

;; Network permissions
(allow network*)
(allow network-bind)
(allow network-outbound)

;; System permissions
(allow process*)
(allow sysctl*)
(allow system-socket)
(allow mach-lookup)
(allow file-ioctl)
EOF

echo "✅ Security profile created: $SANDBOX_PROFILE"
echo "📝 Base sandbox directory: $SANDBOX_BASE_DIR"
echo ""
echo "🚀 To use, add to ~/.zshrc or ~/.bashrc:"
echo "alias sandbox=\"$SCRIPT_DIR/sandbox.sh\"  # Recommended"
echo "# Or add to PATH (alternative):"
echo "# export PATH=\"$SCRIPT_DIR:\$PATH\""
echo "export SANDBOX_BASE_DIR=\"$SANDBOX_BASE_DIR\"  # Optional, to change path"
