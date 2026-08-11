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
BACKUP_ROOT="$PROJECT_ROOT/Backups"
CACHE_ROOT="$PROJECT_ROOT/Cache/Servers"

VERSION_FILE="version.txt"
API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"

EXCLUDE_PATHS=(
    "config"
    "worlds"
    "allowlist.json"
    "permissions.json"
    "server.properties"
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

[ -d "$SERVER_ROOT" ] || {
    err "Servers directory not found: $SERVER_ROOT"
    exit 1
}

for cmd in curl jq wget unzip tar; do
    command -v "$cmd" >/dev/null 2>&1 ||
        { err "$cmd is not installed."; exit 1; }
done

mkdir -p "$BACKUP_ROOT" "$CACHE_ROOT"

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

        1|2)
            if [ "$choice" = "1" ]; then
                TYPE="serverBedrockLinux"
                DEFAULT_DIR="server"
                VERSION_LABEL="Latest Stable"
                info "Fetching latest stable version..."
            else
                TYPE="serverBedrockPreviewLinux"
                DEFAULT_DIR="server_preview"
                VERSION_LABEL="Latest Preview"
                info "Fetching latest preview version..."
            fi

            API_DATA="$(curl -fsSL "$API_URL")" || {
                err "Failed to fetch version information."
                sleep 2
                continue
            }

            DOWNLOAD_URL="$(
                printf '%s' "$API_DATA" |
                jq -r --arg type "$TYPE" \
                    '.result.links[] |
                     select(.downloadType==$type) |
                     .downloadUrl' |
                head -n1
            )"

            if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
                err "Could not find download URL."
                sleep 2
                continue
            fi
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

    VERSION=""

    if [[ "$DOWNLOAD_URL" =~ bedrock-server-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.zip ]]; then
        VERSION="${BASH_REMATCH[1]}"
    elif [[ "$DOWNLOAD_URL" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        VERSION="${BASH_REMATCH[1]}"
    fi

    [ "$choice" = "3" ] && VERSION="$CUSTOM_VERSION"

    if [ -z "$VERSION" ]; then
        err "Could not determine server version."
        sleep 2
        continue
    fi

    CACHE_FILE="$CACHE_ROOT/bedrock_server_${VERSION}.zip"

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

        if [[ -z "$NEW_FOLDER" ||
              "$NEW_FOLDER" == "." ||
              "$NEW_FOLDER" == ".." ||
              "$NEW_FOLDER" == */* ]]; then
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

                if [[ -z "$NEW_FOLDER" ||
                      "$NEW_FOLDER" == "." ||
                      "$NEW_FOLDER" == ".." ||
                      "$NEW_FOLDER" == */* ]]; then
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
    BACKUP_DIR="$BACKUP_ROOT/$SERVER_NAME"

    mkdir -p "$SERVER_DIR" "$BACKUP_DIR"

    echo ""
    echo -e "${BOLD}Version:${RESET} $VERSION"
    echo -e "${BOLD}Server :${RESET} $SERVER_NAME"
    echo ""

    #
    # CACHE
    #

    if [ -f "$CACHE_FILE" ]; then
        info "Checking cached server..."

        if unzip -tq "$CACHE_FILE" >/dev/null 2>&1; then
            ok "Using cached server: $CACHE_FILE"
        else
            warn "Cached archive is invalid. Removing it..."
            rm -f "$CACHE_FILE"
        fi
    fi

    if [ ! -f "$CACHE_FILE" ]; then
        info "Downloading $VERSION..."

        TEMP_ZIP="$CACHE_FILE.tmp"
        rm -f "$TEMP_ZIP"

        if ! wget -q --show-progress "$DOWNLOAD_URL" -O "$TEMP_ZIP"; then
            err "Download failed."
            rm -f "$TEMP_ZIP"
            sleep 2
            continue
        fi

        if ! unzip -tq "$TEMP_ZIP" >/dev/null 2>&1; then
            err "Downloaded archive is invalid."
            rm -f "$TEMP_ZIP"
            sleep 2
            continue
        fi

        if ! unzip -l "$TEMP_ZIP" |
            grep -qE '(^|/)bedrock_server$'; then
            err "Downloaded archive does not contain bedrock_server."
            rm -f "$TEMP_ZIP"
            sleep 2
            continue
        fi

        mv "$TEMP_ZIP" "$CACHE_FILE"

        ok "Server cached: $CACHE_FILE"
    fi

    #
    # BACKUP
    #

    BACKUP_ITEMS=()

    for item in "${EXCLUDE_PATHS[@]}"; do
        [ -e "$SERVER_DIR/$item" ] &&
            BACKUP_ITEMS+=("$item")
    done

    BACKUP_FILE=""

    if [ "${#BACKUP_ITEMS[@]}" -gt 0 ]; then
        BACKUP_FILE="${SERVER_NAME}_update_$(date +%Y%m%d_%H%M%S).tar.gz"

        info "Backing up protected server data..."

        if ! tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
            -C "$SERVER_DIR" "${BACKUP_ITEMS[@]}"; then
            err "Backup failed. Update aborted."
            rm -f "$BACKUP_DIR/$BACKUP_FILE"
            sleep 2
            continue
        fi

        ok "Backup saved: $BACKUP_DIR/$BACKUP_FILE"
    else
        warn "No protected server data found. Skipping backup."
    fi

    #
    # EXTRACT
    #

    TEMP_DIR="$(mktemp -d)"

    cleanup(){
        rm -rf "$TEMP_DIR"
    }

    trap cleanup EXIT

    info "Extracting server files..."

    if ! unzip -q "$CACHE_FILE" -d "$TEMP_DIR"; then
        err "Extraction failed."
        continue
    fi

    if [ ! -f "$TEMP_DIR/bedrock_server" ]; then
        err "bedrock_server not found in archive."
        continue
    fi

    #
    # INSTALL
    #

    info "Installing new server files..."

    for item in "$TEMP_DIR"/* "$TEMP_DIR"/.[!.]* "$TEMP_DIR"/..?*; do
        [ -e "$item" ] || continue

        name="$(basename "$item")"
        protected=false

        for exclude in "${EXCLUDE_PATHS[@]}"; do
            if [ "$name" = "$exclude" ]; then
                protected=true
                break
            fi
        done

        [ "$protected" = true ] && continue

        rm -rf "$SERVER_DIR/$name"
        cp -a "$item" "$SERVER_DIR/$name"
    done

    chmod +x "$SERVER_DIR/bedrock_server"

    #
    # RESTORE PROTECTED DATA
    #

    if [ -n "$BACKUP_FILE" ]; then
        info "Restoring protected server data..."

        if ! tar -xzf "$BACKUP_DIR/$BACKUP_FILE" \
            -C "$SERVER_DIR"; then
            err "Restore failed."
            continue
        fi

        ok "Protected server data restored."
    fi

    printf '%s\n' "$VERSION" > "$SERVER_DIR/$VERSION_FILE"

    cleanup
    trap - EXIT

    echo ""
    ok "Install / update complete."
    echo ""
    echo -e "${BOLD}Version:${RESET} $VERSION"
    echo -e "${BOLD}Server :${RESET} $SERVER_DIR"
    echo -e "${BOLD}Cache  :${RESET} $CACHE_FILE"

    [ -n "$BACKUP_FILE" ] &&
        echo -e "${BOLD}Backup :${RESET} $BACKUP_DIR/$BACKUP_FILE"

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