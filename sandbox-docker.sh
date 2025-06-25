#!/bin/bash

set -e

# === Defaults ===
# Common development ports
PORTS=(
    3000 # React/Node default
    3001 # API default
    5000 # Python/Flask
    5173 # Vite
    8000 # Django/Python
    8080 # Java/Tomcat
    8081 # Alternative Java
    9000 # PHP/Laravel
    4200 # Angular
    1337 # Strapi
)

# Allowed hosts
ALLOWED_HOSTS=(
    "localhost"
    "127.0.0.1"
    "0.0.0.0"
    "host.docker.internal"
)

BASE_CONTAINER_NAME="nrsk-sandbox"

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

    # Apply custom ports if specified
    if [ -n "$CUSTOM_PORTS" ]; then
        IFS=',' read -ra PORTS <<<"$CUSTOM_PORTS"
    fi

    # Apply custom hosts if specified
    if [ -n "$CUSTOM_HOSTS" ]; then
        IFS=',' read -ra ALLOWED_HOSTS <<<"$CUSTOM_HOSTS"
    fi

    REPO_NAME=$(basename -s .git "$REPO_URL")
    BASE_DIR="$HOME/Sandbox"
    TARGET_DIR="$BASE_DIR/$REPO_NAME"

    mkdir -p "$BASE_DIR"

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

    cd "$TARGET_DIR"

    # === Port preparation ===
    PORT_MAPPINGS=""
    USED_PORTS=()
    for PORT in "${PORTS[@]}"; do
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

    CONTAINER_NAME=$(get_available_container_name "$BASE_CONTAINER_NAME")
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
        --memory=2g \
        --cpus=2 \
        --pids-limit=100 \
        --ulimit nofile=1024:1024 \
        --network=bridge \
        ${EXTRA_HOSTS:+"$EXTRA_HOSTS"} \
        -v "$PWD":/app \
        -w /app \
        ${PORT_MAPPINGS:+"$PORT_MAPPINGS"} \
        node:20-slim \
        bash
}

# Run main only if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
