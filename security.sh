#!/bin/bash

# Core (non-removable) blacklist for sensitive paths
SANDBOX_CORE_BLOCKED_PATHS=(
    # SSH и ключи
    "$HOME/.ssh"
    "$HOME/.gnupg"
    "$HOME/.ssh/config"
    "$HOME/.ssh/id_rsa"
    "$HOME/.ssh/id_rsa.pub"

    # Браузеры
    "$HOME/Library/Application Support/Google/Chrome"
    "$HOME/Library/Application Support/Firefox"
    "$HOME/Library/Application Support/Chromium"
    "$HOME/Library/Application Support/Safari"

    # Системные и пользовательские директории
    "$HOME/Documents"
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Movies"
    "$HOME/Music"
    "$HOME/Desktop"

    # Облачные сервисы и конфиги
    "$HOME/.aws"
    "$HOME/.config/gcloud"
    "$HOME/.azure"
    "$HOME/.kube"
    "$HOME/.docker"
    "$HOME/.gitconfig"
    "$HOME/.npmrc"

    # Системные данные и безопасность
    "$HOME/Library/Keychains"
    "$HOME/Library/Application Support/com.apple.TCC"
    "$HOME/Library/Application Support/AddressBook"
    "$HOME/Library/Application Support/iCloud"
    "$HOME/Library/Messages"
    "$HOME/Library/Mail"
    "$HOME/Library/Safari"

    # Системные директории
    "/etc"
    "/private"
    "/System"
    "/Library"
)

# Paths that are exceptions to blocked paths
SANDBOX_EXCEPTIONS=(
    # Кеш
    "$HOME/Library/Caches"
    "$HOME/Library/Caches/npm"
    "$HOME/Library/Caches/yarn"
    "$HOME/Library/Caches/pip"

    # Логи
    "$HOME/Library/Logs"
    "$HOME/Library/Logs/sandbox.log"

    # Временные файлы
    "/private/tmp"
    "/private/var/folders"
    "/private/var/folders/*/T"

    # Пакетные менеджеры
    "$HOME/.npm"
    "$HOME/.yarn/cache"
    "$HOME/.pnpm-store"
    "$HOME/.cache"

    # Системные исключения для работы
    "/private/etc/hosts"
    "/private/etc/resolv.conf"
    "/private/etc/protocols"
    "/private/etc/services"
    "/etc/hosts"
    "/etc/resolv.conf"
    "/etc/protocols"
    "/etc/services"

    # Node.js исключения
    "/usr/local/bin/node"
    "/usr/local/include/node"
    "/usr/local/lib/node_modules"
    "$HOME/.node-gyp"
    "$HOME"
    "/Users"
)

# Пути, которые разрешены для чтения
SANDBOX_READ_PATHS=(
    "/usr/local"        # For node, npm etc.
    "/usr/bin"          # System utilities
    "$HOME/.npm"        # npm cache
    "$HOME/.yarn"       # yarn cache
    "$HOME/.pnpm-store" # pnpm cache
    "$HOME/.cache"      # Common cache
    "$HOME/.nvm"        # Node Version Manager
)

# Generate sandbox profile
generate_security_profile() {
    local profile_path="$1"
    local sandbox_dir="$2"
    local read_paths_str="$3"
    local home_dir="$4"

    # Debug logging
    echo "🔍 Debug: Generating security profile"
    echo "📄 Profile path: $profile_path"
    echo "📁 Sandbox dir: $sandbox_dir"
    echo "🏠 Home dir: $home_dir"
    echo "📝 Read paths: $read_paths_str"

    # Convert comma-separated string back to array
    IFS=',' read -ra read_paths <<<"$read_paths_str"

    # Создаем полный профиль
    cat >"$profile_path" <<EOF
(version 1)
(debug deny)
(deny default)

;; 1. Системные разрешения (необходимый минимум)
(import "system.sb")
(allow process*)
(allow sysctl*)
(allow system-socket)
(allow mach-lookup)
(allow file-ioctl)
(allow network*)

;; 2. Базовые файловые разрешения (только чтение)
(allow file-read*
    (literal "/usr")
    (literal "/bin")
    (literal "/sbin")
    (literal "/Users")
    (literal "$home_dir")
    (subpath "/usr/local/bin")
    (subpath "/usr/local/lib")
    (subpath "/usr/local/include")
)

;; 3. Системные файлы (только чтение) - только нужные
(allow file-read*
    (literal "/etc/hosts")
    (literal "/etc/resolv.conf")
    (literal "/etc/protocols")
    (literal "/etc/services")
    (literal "/private/etc/hosts")
    (literal "/private/etc/resolv.conf")
    (literal "/private/etc/protocols")
    (literal "/private/etc/services")
    (literal "/etc/ssl/openssl.cnf")
    (literal "/System/Library/OpenSSL/openssl.cnf")
    (literal "/System/Library/Security/Certificates.bundle")
    (literal "/usr/lib/system/libsystem_kernel.dylib")
    (literal "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
)

;; 3.1. Системные директории (только чтение)
(allow file-read*
    (subpath "/System/Library/Frameworks")
    (subpath "/System/Library/PrivateFrameworks")
    (subpath "/System/Library/Extensions")
    (subpath "/Library/Extensions")
)

;; 3.2. Системные инструменты (только чтение)
(allow file-read*
    (subpath "/usr/bin")
    (subpath "/bin")
    (subpath "/usr/sbin")
    (subpath "/sbin")
)

;; 4. Разрешения для рабочей директории
(allow file*
    (subpath "$sandbox_dir")
    (subpath "/private/tmp")
    (subpath "/private/var/folders")
)

;; 5. Разрешения для кэша и логов
(allow file*
    (subpath "$home_dir/Library/Caches")
    (subpath "$home_dir/Library/Logs")
    (subpath "$home_dir/.npm")
    (subpath "$home_dir/.yarn")
    (subpath "$home_dir/.pnpm-store")
    (subpath "$home_dir/.cache")
)

;; 6. Разрешения для инструментов разработки
EOF

    # Добавляем разрешения для путей из конфига
    for path in "${read_paths[@]}"; do
        # Replace $HOME with actual home directory
        path=${path/\$HOME/$home_dir}
        # Пропускаем /usr/bin - он уже добавлен как read-only
        if [[ "$path" != "/usr/bin" ]]; then
            echo "(allow file-read* (subpath \"$path\"))" >>"$profile_path"
        fi
    done

    # Добавляем критичные блокировки ПОСЛЕ разрешений
    cat >>"$profile_path" <<EOF

;; 7. КРИТИЧНЫЕ БЛОКИРОВКИ (высший приоритет - переопределяют разрешения выше)
(deny file-read* file-write*
    ;; Блокируем критичные системные файлы
    (literal "/etc/passwd")
    (literal "/etc/shadow")
    (literal "/etc/sudoers")
    (literal "/etc/group")
    (literal "/etc/gshadow")
    (literal "/etc/master.passwd")
    (literal "/private/etc/passwd")
    (literal "/private/etc/shadow")
    (literal "/private/etc/sudoers")
    (literal "/private/etc/group")
    (literal "/private/etc/gshadow")
    (literal "/private/etc/master.passwd")
EOF

    # Добавляем блокировки путей пользователя
    for path in "${SANDBOX_CORE_BLOCKED_PATHS[@]}"; do
        # Replace $HOME with actual home directory
        path=${path/\$HOME/$home_dir}
        # Пропускаем системные директории - они уже заблокированы выше
        if [[ "$path" != "/etc" && "$path" != "/private" && "$path" != "/System" && "$path" != "/Library" ]]; then
            echo "    (subpath \"$path\")" >>"$profile_path"
        fi
    done
    echo ")" >>"$profile_path"

    echo "✅ Security profile created: $profile_path"
}

# Export functions and variables
export -f generate_security_profile
export SANDBOX_CORE_BLOCKED_PATHS
export SANDBOX_EXCEPTIONS
export SANDBOX_READ_PATHS
