# macOS Sandbox - Utility for Secure Development

A utility for isolating potentially dangerous code during development on macOS using the built-in `sandbox-exec` mechanism.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-username/macos-sandbox.git
   cd macos-sandbox
   ```

2. Run the setup script:

   ```bash
   ./sandbox-setup.sh
   ```

3. Add the utility to your shell (the setup script will show exact commands):

   ```bash
   # In ~/.zshrc or ~/.bashrc:
   alias sandbox="/path/to/macos-sandbox/sandbox.sh"  # Recommended

   # Optional: change base directory (default is ~/Sandbox)
   export SANDBOX_BASE_DIR="/desired/path/to/sandbox"
   ```

4. Make scripts executable:

   ```bash
   chmod +x *.sh
   ```

5. Apply changes:

   ```bash
   source ~/.zshrc  # or source ~/.bashrc for Bash
   ```

6. Verify installation:
   ```bash
   sandbox --help  # Should show usage information
   ```

## Usage

### Basic Mode (sandbox-exec)

1. Navigate to a directory inside the sandbox:

   ```bash
   cd $SANDBOX_BASE_DIR/your-project
   ```

2. Run a command through sandbox:

   ```bash
   sandbox npm start
   sandbox yarn dev
   sandbox node server.js
   ```

### Docker Mode (optional)

For running individual repositories in Docker with isolation:

```bash
# Basic usage
sandbox-docker git@github.com:user/repo.git

# Custom ports
sandbox-docker https://github.com/user/repo.git --ports 3000,3001,8080

# Custom hosts
sandbox-docker https://github.com/user/repo.git --hosts localhost,custom.host
```

Preset development ports:

- 3000: React/Node
- 3001: API
- 5000: Python/Flask
- 5173: Vite
- 8000: Django
- 8080: Java/Tomcat
- 8081: Alternative Java
- 9000: PHP/Laravel
- 4200: Angular
- 1337: Strapi

## Security Restrictions

### Basic Mode (sandbox-exec)

- Commands are executed only inside the sandbox ($SANDBOX_BASE_DIR)
- File system access:
  - Reading is allowed everywhere (necessary for package managers)
  - Writing is restricted to sandbox and system directories
- Network access is allowed for development
- System calls are limited by security profile

### Docker Mode

- Resource limits:
  - Memory: 2GB
  - CPU: 2 cores
  - Process limit: 100
  - File descriptors: 1024
- Network:
  - Configurable port forwarding
  - Custom host support
- Security:
  - All capabilities disabled
  - No privilege escalation
  - Network isolation through bridge

## Configuration

Sandbox base directory:

```bash
export SANDBOX_BASE_DIR="/desired/path/to/sandbox"
```

Security profile is located in `$SANDBOX_BASE_DIR/sandbox.profile` and can be customized for your needs.

## Requirements

- macOS (tested on Sonoma 14.0+)
- Bash or Zsh
- Docker (optional, for container mode)

## Security

The utility uses:

1. Basic Mode (sandbox-exec):

   - Built-in macOS isolation mechanism
   - File system access control
   - Network connection management
   - System call restrictions

2. Docker Mode:
   - Container isolation
   - Resource limitations
   - Network isolation
   - Secure container settings

## License

MIT

## Features

- 🔒 File system isolation
- 🌐 Network connection control
- 📁 Personal files and data protection
- ⚡️ Native performance (no Docker overhead)
- 🛠 Development process convenience

## How It Works

### sandbox-exec Mechanism

`sandbox-exec` is a built-in macOS security mechanism based on [Seatbelt](https://www.chromium.org/developers/design-documents/sandbox/osx-sandboxing-design/) technology. It allows:

- Creating isolated environments for processes
- Controlling file system access
- Managing network connections
- Restricting system calls

### Security Profile

Security rules are defined in the `sandbox.profile` file:

```scheme
(version 1)
(allow default)

;; Example rules
(allow network* (remote ip "localhost"))     ; allow localhost
(allow file-write* (subpath "/path"))       ; allow writing
(deny file-write* (subpath "/private"))     ; deny writing
```

Each rule can:

- ✅ Allow (`allow`) or ❌ deny (`deny`) actions
- 🎯 Specify exact paths or patterns
- 🌐 Define network rules
- 🔒 Control system calls

### Isolation Levels

1. **File System**:

   - Full read access (allows npm/yarn to work)
   - Writing restricted to Sandbox directory
   - System and user files protection

2. **Network**:

   - Localhost allowed for local development
   - Outgoing connections allowed for npm/yarn
   - Incoming connection control

3. **Processes**:
   - Process isolation within sandbox
   - New process creation control
   - System call restrictions

### How It Works

1. **Initialization**:

   ```bash
   ./sandbox-setup.sh
   ```

   - Creates profile with rules
   - Sets up access permissions
   - Generates helper scripts

2. **Running Commands**:

   ```bash
   ./sandbox.sh 'npm start'
   ```

   - Checks environment
   - Applies security profile
   - Runs command in isolated environment

3. **Monitoring**:
   - Tracking rule violation attempts
   - Logging suspicious activity
   - Command execution control

### Approach Benefits

1. **Security**:

   - Reliable process isolation
   - File access control
   - Malicious code protection

2. **Performance**:

   - Native macOS performance
   - Minimal overhead
   - No virtualization

3. **Convenience**:
   - Simple command execution
   - Transparent npm/yarn operation
   - Development tool compatibility

### Limitations and Features

1. **System Requirements**:

   - macOS 10.15+ only
   - Requires sandbox-exec execution rights
   - Sandbox directory access needed

2. **Functionality Limitations**:

   - No access to system directories
   - Limited network access
   - Isolation from other processes

3. **Debugging**:
   - Log viewing capability
   - Rule violation control
   - Activity monitoring

## Troubleshooting

1. **"Profile not found" error**

   - Run `sandbox-setup.sh`

2. **"Command must be executed inside Sandbox" error**

   - Ensure you are in `$SANDBOX_BASE_DIR` or its subdirectory

3. **Permission issues**
   - Check directory permissions: `ls -la $SANDBOX_BASE_DIR`
   - If needed: `chmod 700 $SANDBOX_BASE_DIR`

## Development and Testing

### Running Tests

```bash
cd tests
./run_tests.sh          # Run all tests
./run_tests.sh config.bats        # Test configuration
./run_tests.sh sandbox-docker.bats  # Test Docker mode
```

Tests use [bats-core](https://github.com/bats-core/bats-core) and are automatically installed in `~/.local/bin`.

### Test Structure

- `tests/config.bats` - configuration tests
- `tests/sandbox-docker.bats` - Docker mode tests
- `tests/test_helper.bash` - helper functions
- `tests/run_tests.sh` - test runner script

### Docker Mode

For running individual repositories in Docker with isolation:

```bash
# Show help
sandbox-docker --help

# Basic usage
sandbox-docker git@github.com:user/repo.git

# Custom ports (override defaults)
sandbox-docker https://github.com/user/repo.git --ports 3000,3001,8080

# Custom hosts (override defaults)
sandbox-docker https://github.com/user/repo.git --hosts test.local,dev.local
```

Preset development ports:

- 3000: React/Node default
- 3001: API default
- 5000: Python/Flask
- 5173: Vite
- 8000: Django/Python
- 8080: Java/Tomcat
- 8081: Alternative Java
- 9000: PHP/Laravel
- 4200: Angular
- 1337: Strapi

Port handling features:

- If a port is busy, the next available one is automatically selected
- When custom ports are specified, defaults are not used
- Each port is mapped as internal:external

Host handling features:

- `localhost` and `127.0.0.1` are handled specially
- Other hosts get mapped to host-gateway
- When custom hosts are specified, defaults are not used

4. **Test run errors**
   - Ensure you have write permissions for `~/.local`
   - Check if `bats` is installed: `~/.local/bin/bats --version`
   - If issues persist, remove `~/.local/bin/bats` and restart tests
