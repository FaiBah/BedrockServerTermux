#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")/Servers"
VERSION_FILE="version.txt"
API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"
SERVER_ZIP="bedrock_server_latest.zip"

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
    if ! command -v "$cmd" >/dev/null 2>&1; then
        err "$cmd is not installed."
        exit 1
    fi
done

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

            if [ -z "$CUSTOM_VERSION" ]; then
                err "Version cannot be empty."
                sleep 1
                continue
            fi

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

        if [ -f "$dir/$VERSION_FILE" ]; then
            version="$(head -n1 "$dir/$VERSION_FILE" 2>/dev/null || true)"
        fi

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

        if [[ "$NEW_FOLDER" == "." ||
              "$NEW_FOLDER" == ".." ||
              "$NEW_FOLDER" == */* ||
              -z "$NEW_FOLDER" ]]; then
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

                if [[ "$NEW_FOLDER" == "." ||
                      "$NEW_FOLDER" == ".." ||
                      "$NEW_FOLDER" == */* ||
                      -z "$NEW_FOLDER" ]]; then
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
    cd "$SERVER_DIR"

    BACKUP_FILE=""

    if [ -d "worlds" ]; then
        BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        BACKUP_ITEMS=(worlds)

        for file in server.properties permissions.json allowlist.json valid_known_packs.json; do
            [ -f "$file" ] && BACKUP_ITEMS+=("$file")
        done

        info "Backing up worlds and configuration..."

        if ! tar -czf "$BACKUP_FILE" "${BACKUP_ITEMS[@]}"; then
            err "Backup failed. Update aborted."
            sleep 2
            exit 1
        fi

        ok "Backup saved: $SERVER_DIR/$BACKUP_FILE"
    else
        warn "No worlds directory found. Skipping backup."
    fi

    echo ""
    info "Downloading $VERSION_LABEL..."

    rm -f "$SERVER_ZIP"

    if ! wget -q --show-progress "$DOWNLOAD_URL" -O "$SERVER_ZIP"; then
        err "Download failed."
        sleep 2
        exit 1
    fi

    echo ""
    info "Extracting server files..."

    if ! unzip -o "$SERVER_ZIP" >/dev/null; then
        err "Extraction failed."
        sleep 2
        exit 1
    fi

    rm -f "$SERVER_ZIP"

    if [ ! -f "bedrock_server" ]; then
        err "bedrock_server not found after extraction."
        sleep 2
        exit 1
    fi

    chmod +x bedrock_server
    ok "Server files installed."

    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        info "Restoring server configuration..."

        for file in server.properties permissions.json allowlist.json valid_known_packs.json; do
            if tar -xzf "$BACKUP_FILE" -- "$file" 2>/dev/null; then
                ok "Restored $file"
            fi
        done
    fi

    INSTALLED_VERSION=""

    if [[ "$DOWNLOAD_URL" =~ bedrock-server-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.zip ]]; then
        INSTALLED_VERSION="${BASH_REMATCH[1]}"
    elif [[ "$DOWNLOAD_URL" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        INSTALLED_VERSION="${BASH_REMATCH[1]}"
    fi

    if [ "$choice" = "3" ]; then
        INSTALLED_VERSION="$CUSTOM_VERSION"
    fi

    printf '%s\n' "${INSTALLED_VERSION:-$VERSION_LABEL}" > "$VERSION_FILE"

    echo ""
    ok "Install / update complete."
    echo ""
    echo -e "${BOLD}Version:${RESET} $(cat "$VERSION_FILE")"
    echo -e "${BOLD}Server :${RESET} $SERVER_DIR"

    if [ -n "$BACKUP_FILE" ]; then
        echo -e "${BOLD}Backup :${RESET} $SERVER_DIR/$BACKUP_FILE"
    fi

    if [ "$choice" = "2" ]; then
        echo ""
        warn "Preview / Beta requires the Minecraft Preview client."
    fi

    if [ "$choice" = "3" ]; then
        echo ""
        warn "Older versions may be incompatible with your device."
    fi

    echo ""
    info "Returning to version selection..."
    sleep 2
done