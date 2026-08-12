#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SERVER_ROOT="$PROJECT_ROOT/Servers"
CACHE_ROOT="$PROJECT_ROOT/Cache/Servers"
BACKUP_ROOT="$PROJECT_ROOT/Backups"

VERSION_FILE="version.txt"
API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"

BACKUP_PATHS=(
    config
    allowlist.json
    permissions.json
    server.properties
)

KEEP_PATHS=(
    worlds
    config
    allowlist.json
    permissions.json
    server.properties
    version.txt
)

title(){
    clear
    echo ""
    echo -e "${BOLD}${CYAN}Install / Update Server${RESET}"
    echo "-----------------------"
    echo ""
}

if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run inside Debian as root."
    exit 1
fi

if [ ! -d "$SERVER_ROOT" ]; then
    err "Servers directory not found: $SERVER_ROOT"
    exit 1
fi

for cmd in curl jq wget unzip tar; do
    command -v "$cmd" >/dev/null 2>&1 ||
        { err "$cmd is not installed."; exit 1; }
done

mkdir -p "$CACHE_ROOT" "$BACKUP_ROOT"

while true; do
    SERVERS=()

    for dir in "$SERVER_ROOT"/*; do
        [ -d "$dir" ] && SERVERS+=("$dir")
    done

    title

    echo -e "${BOLD}Select Version:${RESET}"
    echo ""
    echo -e "  ${CYAN}1)${RESET} Latest Stable"
    echo -e "  ${CYAN}2)${RESET} Latest Preview / Beta"
    echo -e "  ${CYAN}3)${RESET} Specific Version"
    echo -e "  ${CYAN}0)${RESET} Back"
    echo ""

    read -rp "Select an option [0-3]: " choice

    case "$choice" in
        0)
            info "Back to manage menu..."
            exit 0
            ;;

        1)
            info "Fetching latest stable version..."

            DOWNLOAD_URL="$(
                curl -fsSL "$API_URL" |
                jq -r '.result.links[] |
                    select(.downloadType=="serverBedrockLinux") |
                    .downloadUrl' |
                head -n1
            )"

            if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
                err "Could not find latest stable download URL."
                sleep 2
                continue
            fi

            DEFAULT_DIR="server"
            VERSION_LABEL="Latest Stable"
            ;;

        2)
            info "Fetching latest preview version..."

            DOWNLOAD_URL="$(
                curl -fsSL "$API_URL" |
                jq -r '.result.links[] |
                    select(.downloadType=="serverBedrockPreviewLinux") |
                    .downloadUrl' |
                head -n1
            )"

            if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
                err "Could not find latest preview download URL."
                sleep 2
                continue
            fi

            DEFAULT_DIR="server_preview"
            VERSION_LABEL="Latest Preview"
            ;;

        3)
            echo ""
            read -rp "Enter version number: " CUSTOM_VERSION

            if ! [[ "$CUSTOM_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                err "Invalid version format."
                sleep 1
                continue
            fi

            DOWNLOAD_URL="https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-${CUSTOM_VERSION}.zip"
            DEFAULT_DIR="server_${CUSTOM_VERSION}"
            VERSION_LABEL="$CUSTOM_VERSION"

            warn "Older versions may not work on ARM."
            ;;

        *)
            err "Invalid option."
            sleep 1
            continue
            ;;
    esac

    echo ""
    echo -e "${BOLD}Select Target Server:${RESET}"
    echo ""

    for i in "${!SERVERS[@]}"; do
        dir="${SERVERS[$i]}"
        name="$(basename "$dir")"
        version=""

        [ -f "$dir/$VERSION_FILE" ] &&
            version="$(head -n1 "$dir/$VERSION_FILE" 2>/dev/null || true)"

        if [ "$name" = "$DEFAULT_DIR" ]; then
            echo -e "  ${CYAN}$((i + 1)))${RESET} $name ${GREEN}(recommended)${RESET}"
        elif [ -n "$version" ]; then
            echo -e "  ${CYAN}$((i + 1)))${RESET} $name ${GREEN}(v$version)${RESET}"
        else
            echo -e "  ${CYAN}$((i + 1)))${RESET} $name"
        fi
    done

    echo -e "  ${CYAN}N)${RESET} Create New Server"
    echo -e "  ${CYAN}0)${RESET} Back"
    echo ""

    if [ "${#SERVERS[@]}" -eq 0 ]; then
        read -rp "Enter server name [$DEFAULT_DIR]: " NEW_FOLDER
        NEW_FOLDER="${NEW_FOLDER:-$DEFAULT_DIR}"

        if [[ "$NEW_FOLDER" == "." || "$NEW_FOLDER" == ".." ||
              "$NEW_FOLDER" == */* || -z "$NEW_FOLDER" ]]; then
            err "Invalid server name."
            sleep 1
            continue
        fi

        SERVER_DIR="$SERVER_ROOT/$NEW_FOLDER"
    else
        read -rp "Select an option: " folder_choice

        case "$folder_choice" in
            0)
                continue
                ;;

            [Nn])
                read -rp "Enter server name [$DEFAULT_DIR]: " NEW_FOLDER
                NEW_FOLDER="${NEW_FOLDER:-$DEFAULT_DIR}"

                if [[ "$NEW_FOLDER" == "." || "$NEW_FOLDER" == ".." ||
                      "$NEW_FOLDER" == */* || -z "$NEW_FOLDER" ]]; then
                    err "Invalid server name."
                    sleep 1
                    continue
                fi

                SERVER_DIR="$SERVER_ROOT/$NEW_FOLDER"
                ;;

            *)
                if [[ "$folder_choice" =~ ^[0-9]+$ ]] &&
                   [ "$folder_choice" -ge 1 ] &&
                   [ "$folder_choice" -le "${#SERVERS[@]}" ]; then
                    SERVER_DIR="${SERVERS[$((folder_choice - 1))]}"
                else
                    err "Invalid option."
                    sleep 1
                    continue
                fi
                ;;
        esac
    fi

    SERVER_NAME="$(basename "$SERVER_DIR")"

    echo ""
    echo -e "${BOLD}Version:${RESET} $VERSION_LABEL"
    echo -e "${BOLD}Server :${RESET} $SERVER_NAME"
    echo ""

    mkdir -p "$SERVER_DIR"

    INSTALLED_VERSION=""

    if [[ "$DOWNLOAD_URL" =~ bedrock-server-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.zip ]]; then
        INSTALLED_VERSION="${BASH_REMATCH[1]}"
    elif [[ "$DOWNLOAD_URL" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        INSTALLED_VERSION="${BASH_REMATCH[1]}"
    fi

    [ "$choice" = "3" ] && INSTALLED_VERSION="$CUSTOM_VERSION"

    if [ -z "$INSTALLED_VERSION" ]; then
        err "Could not determine server version."
        sleep 2
        continue
    fi

    CACHE_FILE="$CACHE_ROOT/bedrock-server-${INSTALLED_VERSION}.zip"
    TEMP_CACHE="$CACHE_FILE.tmp"

    echo ""

    if [ -s "$CACHE_FILE" ] && unzip -tq "$CACHE_FILE" >/dev/null 2>&1; then
        info "Using cached BDS: $(basename "$CACHE_FILE")"
    else
        [ -f "$CACHE_FILE" ] && warn "Cached ZIP is invalid. Re-downloading."
        rm -f "$CACHE_FILE" "$TEMP_CACHE"

        info "Downloading BDS $INSTALLED_VERSION..."

        if ! wget -q --show-progress "$DOWNLOAD_URL" -O "$TEMP_CACHE"; then
            err "Download failed."
            rm -f "$TEMP_CACHE"
            sleep 2
            continue
        fi

        if [ ! -s "$TEMP_CACHE" ]; then
            err "Downloaded ZIP is empty."
            rm -f "$TEMP_CACHE"
            sleep 2
            continue
        fi

        info "Validating BDS archive..."

        if ! unzip -tq "$TEMP_CACHE" >/dev/null 2>&1; then
            err "Downloaded ZIP is invalid or corrupted."
            rm -f "$TEMP_CACHE"
            sleep 2
            continue
        fi

        mv "$TEMP_CACHE" "$CACHE_FILE"
        ok "BDS cached: $CACHE_FILE"
    fi

    if ! unzip -tq "$CACHE_FILE" >/dev/null 2>&1; then
        err "Cached BDS archive is invalid."
        sleep 2
        continue
    fi

    BACKUP_FILE=""
    BACKUP_DIR="$BACKUP_ROOT/$SERVER_NAME"
    BACKUP_ITEMS=()

    for path in "${BACKUP_PATHS[@]}"; do
        [ -e "$SERVER_DIR/$path" ] && BACKUP_ITEMS+=("$path")
    done

    if [ "${#BACKUP_ITEMS[@]}" -gt 0 ]; then
        mkdir -p "$BACKUP_DIR"

        BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

        info "Backing up server configuration..."

        if ! tar -czf "$BACKUP_PATH" \
            -C "$SERVER_DIR" \
            "${BACKUP_ITEMS[@]}"; then
            err "Backup failed. Update aborted."
            rm -f "$BACKUP_PATH"
            sleep 2
            continue
        fi

        ok "Backup saved: $BACKUP_PATH"
    else
        warn "No configuration files found. Skipping backup."
    fi

    echo ""
    info "Removing old server files..."

    FIND_ARGS=()

    for path in "${KEEP_PATHS[@]}"; do
        FIND_ARGS+=(-not -name "$path")
    done

    find "$SERVER_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        "${FIND_ARGS[@]}" \
        -exec rm -rf {} +

    ok "Old server files removed."

    echo ""
    info "Extracting server files..."

    UNZIP_EXCLUDES=()

    for path in "${KEEP_PATHS[@]}"; do
        UNZIP_EXCLUDES+=("$path" "$path/*")
    done

    if ! unzip -o "$CACHE_FILE" \
        -d "$SERVER_DIR" \
        -x "${UNZIP_EXCLUDES[@]}" >/dev/null; then
        err "Extraction failed."
        sleep 2
        continue
    fi

    if [ ! -f "$SERVER_DIR/bedrock_server" ]; then
        err "bedrock_server not found after extraction."
        sleep 2
        continue
    fi

    chmod +x "$SERVER_DIR/bedrock_server"
    printf '%s\n' "$INSTALLED_VERSION" > "$SERVER_DIR/$VERSION_FILE"

    ok "Server files installed."

    echo ""
    ok "Install / update complete."
    echo ""
    echo -e "${BOLD}Version:${RESET} $INSTALLED_VERSION"
    echo -e "${BOLD}Server :${RESET} $SERVER_DIR"

    [ -n "$BACKUP_FILE" ] &&
        echo -e "${BOLD}Backup :${RESET} $BACKUP_PATH"

    echo -e "${BOLD}Cache  :${RESET} $CACHE_FILE"

    if [ "$choice" = "2" ]; then
        echo ""
        warn "Preview / Beta requires the Minecraft Preview client."
    elif [ "$choice" = "3" ]; then
        echo ""
        warn "Older versions may be incompatible with your device."
    fi

    echo ""
    info "Returning to version selection..."
    sleep 2
done
