#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info() { echo -e "${CYAN}[*]${RESET} $1"; }
ok()   { echo -e "${GREEN}[✓]${RESET} $1"; }
warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
err()  { echo -e "${RED}[✗]${RESET} $1"; }

TITLE="Install / Update Server"
SHOW_TITLE=true
CLEAR_SCREEN=true

API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"
SERVER_ZIP="bedrock_server_latest.zip"
SERVER_ROOT="$HOME/Bedrock Server/Data"
VERSION_FILE_NAME="version.txt"

show_title() {
    [ "$CLEAR_SCREEN" = true ] && clear

    if [ "$SHOW_TITLE" = true ]; then
        echo ""
        echo -e "${BOLD}${CYAN}========================================${RESET}"
        echo -e "${BOLD}        ${TITLE}${RESET}"
        echo -e "${BOLD}${CYAN}========================================${RESET}"
        echo ""
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run inside Debian as root."
    exit 1
fi

if [ ! -d "$SERVER_ROOT" ]; then
    err "Bedrock Server Data directory not found: $SERVER_ROOT"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    err "curl is not installed."
fi

if ! command -v jq >/dev/null 2>&1; then
    err "jq is not installed."
fi

if ! command -v wget >/dev/null 2>&1; then
    err "wget is not installed."
fi

if ! command -v unzip >/dev/null 2>&1; then
    err "unzip is not installed."
fi

while true; do

    SERVER_FOLDERS=()

    for folder in "$SERVER_ROOT"/*; do
        [ -d "$folder" ] && SERVER_FOLDERS+=("$folder")
    done

    show_title

    # --------------------------------------------------------
    # Select version
    # --------------------------------------------------------

    echo -e "${BOLD}Select version to install:${RESET}"
    echo -e "  ${CYAN}1)${RESET} Latest Stable       ${GREEN}(Recommended)${RESET}"
    echo -e "  ${CYAN}2)${RESET} Latest Preview/Beta"
    echo -e "  ${CYAN}3)${RESET} Specific version    (e.g. 1.26.10.20)"
    echo -e "  ${CYAN}0)${RESET} Back"
    echo ""

    read -rp "Enter choice [0-3]: " VERSION_CHOICE

    case "$VERSION_CHOICE" in

        0)
            info "Back to manage menu..."
            exit 0
            ;;

        1)
            info "Fetching latest stable URL..."

            DOWNLOAD_URL="$(
                curl -fsSL "$API_URL" |
                jq -r '.result.links[] |
                    select(.downloadType=="serverBedrockLinux") |
                    .downloadUrl' |
                head -n1
            )"

            if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
                err "Could not resolve latest stable download URL."
                sleep 1
                continue
            fi

            DEFAULT_DIR="server"
            VERSION_LABEL="Latest Stable"
            ;;

        2)
            info "Fetching latest preview URL..."

            DOWNLOAD_URL="$(
                curl -fsSL "$API_URL" |
                jq -r '.result.links[] |
                    select(.downloadType=="serverBedrockPreviewLinux") |
                    .downloadUrl' |
                head -n1
            )"

            if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
                err "Could not resolve latest preview download URL."
                sleep 1
                continue
            fi

            DEFAULT_DIR="server_preview"
            VERSION_LABEL="Latest Preview"
            ;;

        3)
            echo ""
            read -rp "Enter version number (e.g. 1.26.10.4): " CUSTOM_VERSION

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
            err "Invalid choice."
            sleep 1
            continue
            ;;
    esac


    # --------------------------------------------------------
    # Select target folder
    # --------------------------------------------------------

    echo ""
    echo -e "${BOLD}Select target folder:${RESET}"

    if [ ${#SERVER_FOLDERS[@]} -gt 0 ]; then

        INDEX=1

        for folder in "${SERVER_FOLDERS[@]}"; do

            NAME="$(basename "$folder")"

            VERSION_INFO=""

            if [ -f "$folder/$VERSION_FILE_NAME" ]; then
                VERSION_INFO="$(head -n1 "$folder/$VERSION_FILE_NAME" 2>/dev/null || true)"
            fi

            if [ "$NAME" = "$DEFAULT_DIR" ]; then

                if [ -n "$VERSION_INFO" ]; then
                    echo -e "  ${CYAN}${INDEX})${RESET} $NAME ${GREEN}(v$VERSION_INFO, recommended)${RESET}"
                else
                    echo -e "  ${CYAN}${INDEX})${RESET} $NAME ${GREEN}(recommended)${RESET}"
                fi

            else

                if [ -n "$VERSION_INFO" ]; then
                    echo -e "  ${CYAN}${INDEX})${RESET} $NAME ${GREEN}(v$VERSION_INFO)${RESET}"
                else
                    echo -e "  ${CYAN}${INDEX})${RESET} $NAME"
                fi

            fi

            INDEX=$((INDEX + 1))

        done
    fi

    echo -e "  ${CYAN}N)${RESET} Create a new folder"
    echo -e "  ${CYAN}0)${RESET} Back"
    echo ""

    if [ ${#SERVER_FOLDERS[@]} -eq 0 ]; then

        read -rp "Enter folder name [${DEFAULT_DIR}]: " NEW_FOLDER

        if [ -z "$NEW_FOLDER" ]; then
            NEW_FOLDER="$DEFAULT_DIR"
        fi

        SERVER_DIR="$SERVER_ROOT/$NEW_FOLDER"

    else

        read -rp "Enter choice: " FOLDER_CHOICE

        if [ "$FOLDER_CHOICE" = "0" ]; then

            info "Back to version selection..."
            sleep 1
            continue

        elif [[ "$FOLDER_CHOICE" =~ ^[Nn]$ ]]; then

            read -rp "Enter new folder name [${DEFAULT_DIR}]: " NEW_FOLDER

            if [ -z "$NEW_FOLDER" ]; then
                NEW_FOLDER="$DEFAULT_DIR"
            fi

            SERVER_DIR="$SERVER_ROOT/$NEW_FOLDER"

        elif [[ "$FOLDER_CHOICE" =~ ^[0-9]+$ ]] &&
             [ "$FOLDER_CHOICE" -ge 1 ] &&
             [ "$FOLDER_CHOICE" -le "${#SERVER_FOLDERS[@]}" ]; then

            SERVER_DIR="${SERVER_FOLDERS[$((FOLDER_CHOICE - 1))]}"

        else

            err "Invalid folder choice."
            sleep 1
            continue

        fi
    fi

    SERVER_NAME="$(basename "$SERVER_DIR")"


    # --------------------------------------------------------
    # Show selection
    # --------------------------------------------------------

    echo ""
    ok "Version : $VERSION_LABEL"
    ok "Folder  : $SERVER_DIR"
    echo ""

    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR"


    # --------------------------------------------------------
    # Backup worlds before update
    # --------------------------------------------------------

    if [ -d "worlds" ]; then

        TS="$(date +%Y%m%d_%H%M%S)"
        BACKUP_FILE="worlds_backup_${TS}.tar.gz"

        info "Backing up worlds -> $BACKUP_FILE..."

        if ! tar -czf "$BACKUP_FILE" worlds; then
            err "Backup failed. Aborting to protect your worlds."
            sleep 1
            continue
        fi

        ok "Backup saved: $BACKUP_FILE"

    else

        warn "No 'worlds' directory found - skipping backup."

    fi


    # --------------------------------------------------------
    # Download
    # --------------------------------------------------------

    echo ""
    info "Downloading $VERSION_LABEL..."

    rm -f "$SERVER_ZIP"

    if ! wget -q --show-progress "$DOWNLOAD_URL" -O "$SERVER_ZIP"; then
        err "Download failed."
        sleep 1
        continue
    fi


    # --------------------------------------------------------
    # Extract
    # --------------------------------------------------------

    echo ""
    info "Extracting server files..."

    if ! unzip -o "$SERVER_ZIP"; then
        err "Extraction failed."
        sleep 1
        continue
    fi

    rm -f "$SERVER_ZIP"


    # --------------------------------------------------------
    # Check server
    # --------------------------------------------------------

    if [ -f "bedrock_server" ]; then

        chmod +x bedrock_server
        ok "bedrock_server marked executable."

    else

        err "bedrock_server not found after extraction."
        sleep 1
        continue

    fi


    # --------------------------------------------------------
    # Store installed version
    # --------------------------------------------------------

    if [ "$VERSION_CHOICE" = "1" ] || [ "$VERSION_CHOICE" = "2" ]; then

        INSTALLED_VERSION=""

        if [[ "$DOWNLOAD_URL" =~ bedrock-server-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.zip ]]; then
            INSTALLED_VERSION="${BASH_REMATCH[1]}"
        fi

        if [ -z "$INSTALLED_VERSION" ]; then

            if [[ "$DOWNLOAD_URL" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                INSTALLED_VERSION="${BASH_REMATCH[1]}"
            fi

        fi

        if [ -n "$INSTALLED_VERSION" ]; then

            printf '%s\n' "$INSTALLED_VERSION" > "$VERSION_FILE_NAME"

            ok "Installed version: $INSTALLED_VERSION"

        else

            printf '%s\n' "$VERSION_LABEL" > "$VERSION_FILE_NAME"

            ok "Version saved: $VERSION_LABEL"

        fi

    else

        printf '%s\n' "$CUSTOM_VERSION" > "$VERSION_FILE_NAME"

        ok "Installed version: $CUSTOM_VERSION"

    fi


    # --------------------------------------------------------
    # Complete
    # --------------------------------------------------------

    echo ""
    echo -e "${GREEN}${BOLD}✓ Install/update complete!${RESET}"
    echo ""
    echo -e "  ${BOLD}Version:${RESET} $(cat "$VERSION_FILE_NAME")"
    echo -e "  ${BOLD}Folder :${RESET} $SERVER_DIR"
    echo ""

    if [ "$VERSION_CHOICE" = "2" ]; then
        warn "Preview/Beta: players need Minecraft Preview client to connect."
    fi

    if [ "$VERSION_CHOICE" = "3" ]; then
        warn "If the server crashes immediately, this version may be incompatible with your device."
    fi

    echo ""
    info "Returning to server selection..."
    sleep 2

done