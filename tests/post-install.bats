#!/usr/bin/env bats

# Post-install tests verify sandbox security in the real environment
# These tests should be run AFTER sandbox installation and configuration

# Check required environment variables and files
@test "check required environment variables" {
    [ -n "$SANDBOX_BASE_DIR" ]
    [ -d "$SANDBOX_BASE_DIR" ]
    [ -f "$SANDBOX_BASE_DIR/sandbox.profile" ]
}

# Verify sandbox directory permissions
@test "check sandbox directory permissions" {
    perms=$(stat -f "%OLp" "$SANDBOX_BASE_DIR")
    [ "$perms" = "700" ]
}

setup() {
    # Create test project in the real sandbox environment
    TEST_PROJECT="$SANDBOX_BASE_DIR/security-test-$$"
    mkdir -p "$TEST_PROJECT"
    cd "$TEST_PROJECT"

    # Create Node.js script for filesystem access testing
    cat >test_security.js <<'EOF'
const fs = require('fs');
const path = require('path');

const testPath = process.argv[2];
const action = process.argv[3];

if (action === 'read') {
    try {
        fs.readFileSync(testPath);
        console.log(`SUCCESS: Read ${testPath}`);
        process.exit(0);
    } catch (e) {
        console.error(`DENIED: Read ${testPath}`);
        process.exit(1);
    }
} else if (action === 'write') {
    try {
        fs.writeFileSync(testPath, 'test');
        console.log(`SUCCESS: Write ${testPath}`);
        process.exit(0);
    } catch (e) {
        console.error(`DENIED: Write ${testPath}`);
        process.exit(1);
    }
}
EOF

    # Create Python script for network access testing
    cat >test_network.py <<'EOF'
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])

try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1)
    result = sock.connect_ex((host, port))
    if result == 0:
        print(f"SUCCESS: Connected to {host}:{port}")
        sys.exit(0)
    else:
        print(f"DENIED: Connection to {host}:{port}")
        sys.exit(1)
except Exception as e:
    print(f"ERROR: {str(e)}")
    sys.exit(1)
finally:
    sock.close()
EOF
}

teardown() {
    cd "$SANDBOX_BASE_DIR"
    rm -rf "$TEST_PROJECT"
}

# Filesystem Security Tests
@test "sandbox blocks write access to /tmp" {
    run sandbox node test_security.js "/tmp/test.txt" "write"
    [ "$status" -eq 1 ]
    [[ "${output}" == *"DENIED"* ]]
}

@test "sandbox blocks write access to HOME" {
    run sandbox node test_security.js "$HOME/test.txt" "write"
    [ "$status" -eq 1 ]
    [[ "${output}" == *"DENIED"* ]]
}

@test "sandbox allows write access to SANDBOX_BASE_DIR" {
    run sandbox node test_security.js "./test.txt" "write"
    [ "$status" -eq 0 ]
    [[ "${output}" == *"SUCCESS"* ]]
}

@test "sandbox blocks read access to sensitive files" {
    run sandbox node test_security.js "$HOME/.ssh/config" "read"
    [ "$status" -eq 1 ]
    [[ "${output}" == *"DENIED"* ]]
}

# Network Security Tests
@test "sandbox allows localhost connections" {
    run sandbox python3 test_network.py "localhost" "3000"
    [ "$status" -eq 0 ]
    [[ "${output}" == *"SUCCESS"* ]]
}

@test "sandbox blocks outbound connections to restricted ports" {
    run sandbox python3 test_network.py "example.com" "21"
    [ "$status" -eq 1 ]
    [[ "${output}" == *"DENIED"* ]]
}

# Process Security Tests
@test "sandbox blocks dangerous system commands" {
    run sandbox rm -rf /
    [ "$status" -eq 1 ]
}

@test "sandbox allows safe system commands" {
    run sandbox ls
    [ "$status" -eq 0 ]
}
