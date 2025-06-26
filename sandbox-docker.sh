#!/bin/bash

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || {
    echo "❌ Error: failed to determine script directory"
    exit 1
}
source "$SCRIPT_DIR/config.sh"

# === Functions ===
get_available_container_name() {
    local base_name=$1
    local name=$base_name
    local counter=1

    while docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; do
        name="${base_name}-${counter}"
        ((counter++))
    done

    echo "$name"
}

is_port_available() {
    local port=$1
    ! lsof -i ":$port" >/dev/null 2>&1
}

get_available_port() {
    local start_port=$1
    local excluded_ports=("${@:2}")
    local port=$start_port

    while ! is_port_available "$port" || [[ " ${excluded_ports[*]} " == *" $port "* ]]; do
        ((port++))
    done

    echo "$port"
}

check_path_safety() {
    local path="$1"

    # Проверяем, что путь находится внутри SANDBOX_BASE_DIR
    if [[ "$path" != "$SANDBOX_BASE_DIR"* ]]; then
        echo "❌ Error: path must be inside sandbox: $path"
        return 1
    fi

    # Проверяем на наличие симлинков, ведущих за пределы песочницы
    if [ -L "$path" ]; then
        local real_path
        real_path=$(readlink -f "$path")
        if [[ "$real_path" != "$SANDBOX_BASE_DIR"* ]]; then
            echo "❌ Error: symlink points outside sandbox: $path -> $real_path"
            return 1
        fi
    fi

    # Проверяем все родительские директории на симлинки
    local current="$path"
    while [[ "$current" != "$SANDBOX_BASE_DIR" && "$current" != "/" ]]; do
        if [ -L "$current" ]; then
            local real_path
            real_path=$(readlink -f "$current")
            if [[ "$real_path" != "$SANDBOX_BASE_DIR"* ]]; then
                echo "❌ Error: parent directory symlink points outside sandbox: $current -> $real_path"
                return 1
            fi
        fi
        current=$(dirname "$current")
    done

    return 0
}

show_help() {
    echo "Docker Sandbox - secure repository execution in Docker"
    echo ""
    echo "Usage:"
    echo "  sandbox-docker <git-url> [--ports port1,port2,...] [--hosts host1,host2,...]"
    echo ""
    echo "Examples:"
    echo "  sandbox-docker git@github.com:user/repo.git"
    echo "  sandbox-docker https://github.com/user/repo.git --ports 3000,3001,8080"
    echo "  sandbox-docker https://github.com/user/repo.git --hosts localhost,custom.host"
    exit 0
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker is not installed"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker daemon is not running"
        exit 1
    fi
}

main() {
    # === Help ===
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
    fi

    # === Check Docker ===
    check_docker

    # === Parameters ===
    if [ -z "$1" ]; then
        echo "❌ Please specify repository URL. Example: sandbox-docker git@github.com:user/repo.git"
        exit 1
    fi

    REPO_URL=""
    CUSTOM_PORTS=""
    CUSTOM_HOSTS=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --ports)
            CUSTOM_PORTS="$2"
            shift 2
            ;;
        --hosts)
            CUSTOM_HOSTS="$2"
            shift 2
            ;;
        *)
            REPO_URL="$1"
            shift
            ;;
        esac
    done

    # Use default or custom ports
    PORTS=("${DOCKER_DEFAULT_PORTS[@]}")
    if [ -n "$CUSTOM_PORTS" ]; then
        IFS=',' read -ra PORTS <<<"$CUSTOM_PORTS"
    fi

    # Use default or custom hosts
    ALLOWED_HOSTS=("${DOCKER_DEFAULT_HOSTS[@]}")
    if [ -n "$CUSTOM_HOSTS" ]; then
        IFS=',' read -ra ALLOWED_HOSTS <<<"$CUSTOM_HOSTS"
    fi

    REPO_NAME=$(basename -s .git "$REPO_URL")
    TARGET_DIR="$SANDBOX_BASE_DIR/$REPO_NAME"

    mkdir -p "$SANDBOX_BASE_DIR"

    # === Security checks ===
    if ! check_path_safety "$TARGET_DIR"; then
        exit 1
    fi

    # Check sandbox directory permissions
    if [ "$(stat -f "%OLp" "$SANDBOX_BASE_DIR")" != "700" ]; then
        echo "❌ Error: sandbox directory must have 700 permissions"
        echo "🔧 Run: chmod 700 $SANDBOX_BASE_DIR"
        exit 1
    fi

    # === Cloning ===
    if [ ! -d "$TARGET_DIR" ]; then
        echo "📥 Cloning $REPO_URL → $TARGET_DIR"
        if ! git clone "$REPO_URL" "$TARGET_DIR"; then
            echo "❌ Repository cloning error"
            exit 1
        fi
    else
        echo "📁 Repository already exists: $TARGET_DIR"
    fi

    cd "$TARGET_DIR" || {
        echo "❌ Failed to change directory to $TARGET_DIR"
        exit 1
    }

    # === Port preparation ===
    PORT_MAPPINGS=""
    USED_PORTS=()
    for PORT in "${PORTS[@]}"; do
        # Validate port number
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
            echo "❌ Invalid port number: $PORT"
            exit 1
        fi
        AVAILABLE_PORT=$(get_available_port "$PORT" "${USED_PORTS[@]}")
        USED_PORTS+=("$AVAILABLE_PORT")
        PORT_MAPPINGS="$PORT_MAPPINGS -p $AVAILABLE_PORT:$PORT"
    done

    # === Container launch ===
    echo "🚀 Starting Docker container"
    echo "📌 Mapped ports:"
    for i in "${!PORTS[@]}"; do
        echo "   ${PORTS[$i]} → ${USED_PORTS[$i]}"
    done

    CONTAINER_NAME=$(get_available_container_name "$DOCKER_CONTAINER_PREFIX")
    echo "🐳 Using container name: $CONTAINER_NAME"

    # Form extra_hosts parameters
    EXTRA_HOSTS=""
    for HOST in "${ALLOWED_HOSTS[@]}"; do
        if [ "$HOST" != "localhost" ] && [ "$HOST" != "127.0.0.1" ]; then
            EXTRA_HOSTS="$EXTRA_HOSTS --add-host=$HOST:host-gateway"
        fi
    done

    docker run -it --rm \
        --name "$CONTAINER_NAME" \
        --cap-drop=ALL \
        --security-opt=no-new-privileges \
        --security-opt=seccomp=unconfined \
        --memory="$DOCKER_MEMORY_LIMIT" \
        --cpus="$DOCKER_CPU_LIMIT" \
        --pids-limit="$DOCKER_PIDS_LIMIT" \
        --ulimit nofile="$DOCKER_FILES_LIMIT":"$DOCKER_FILES_LIMIT" \
        --network=bridge \
        ${EXTRA_HOSTS:+"$EXTRA_HOSTS"} \
        -v "$PWD":/app:ro \
        -w /app \
        ${PORT_MAPPINGS:+"$PORT_MAPPINGS"} \
        "$DOCKER_DEFAULT_IMAGE" \
        bash
}

# Run main only if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
