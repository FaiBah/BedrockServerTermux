#!/bin/bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; exit 1; }

TITLE="Install / Update Server"
API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"
SERVER_ZIP="bedrock_server_latest.zip"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")/Servers"

VERSION_FILE_NAME="version.txt"

show_title(){
    clear
    echo ""
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo -e "${BOLD}        $TITLE${RESET}"
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo ""
}

# ── Check environment ───────────────────────────────────────
[ "$(id -u)" -eq 0 ] ||
    err "This script must be run inside Debian as root."

[ -d "$SERVER_ROOT" ] ||
    err "Servers directory not found: $SERVER_ROOT"

# ── Check dependencies ──────────────────────────────────────
for cmd in curl jq wget unzip tar; do
    command -v "$cmd" >/dev/null 2>&1 ||
        err "$cmd is not installed."
done

# ── Version and server selection ────────────────────────────
while true; do
    SERVER_FOLDERS=()

    for folder in "$SERVER_ROOT"/*; do
        [ -d "$folder" ] && SERVER_FOLDERS+=("$folder")
    done

    show_title

    # ── Select version ──────────────────────────────────────
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

            [ -n "$DOWNLOAD_URL" ] &&
            [ "$DOWNLOAD_URL" != "null" ] ||
                err "Could not resolve latest stable download URL."

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

            [ -n "$DOWNLOAD_URL" ] &&
            [ "$DOWNLOAD_URL" != "null" ] ||
                err "Could not resolve latest preview download URL."

            DEFAULT_DIR="server_preview"
            VERSION_LABEL="Latest Preview"
            ;;

        3)
            echo ""
            read -rp "Enter version number (e.g. 1.26.10.4): " CUSTOM_VERSION

            [ -n "$CUSTOM_VERSION" ] ||
                err "Version cannot be empty."

            [[ "$CUSTOM_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
                err "Invalid version format."

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

    # ── Select target folder ─────────────────────────────────
    echo ""
    echo -e "${BOLD}Select target folder:${RESET}"

    for i in "${!SERVER_FOLDERS[@]}"; do
        folder="${SERVER_FOLDERS[$i]}"
        name="$(basename "$folder")"
        version=""

        [ -f "$folder/$VERSION_FILE_NAME" ] &&
            version="$(head -n1 "$folder/$VERSION_FILE_NAME" 2>/dev/null || true)"

        if [ "$name" = "$DEFAULT_DIR" ]; then
            if [ -n "$version" ]; then
                echo -e "  ${CYAN}$((i+1)))${RESET} $name ${GREEN}(v$version, recommended)${RESET}"
            else
                echo -e "  ${CYAN}$((i+1)))${RESET} $name ${GREEN}(recommended)${RESET}"
            fi
        elif [ -n "$version" ]; then
            echo -e "  ${CYAN}$((i+1)))${RESET} $name ${GREEN}(v$version)${RESET}"
        else
            echo -e "  ${CYAN}$((i+1)))${RESET} $name"
        fi
    done

    echo -e "  ${CYAN}N)${RESET} Create a new folder"
    echo -e "  ${CYAN}0)${RESET} Back"
    echo ""

    if [ "${#SERVER_FOLDERS[@]}" -eq 0 ]; then
        read -rp "Enter folder name [$DEFAULT_DIR]: " NEW_FOLDER
        NEW_FOLDER="${NEW_FOLDER:-$DEFAULT_DIR}"
        SERVER_DIR="$SERVER_ROOT/$NEW_FOLDER"
    else
        read -rp "Enter choice: " FOLDER_CHOICE

        if [ "$FOLDER_CHOICE" = "0" ]; then
            info "Back to version selection..."
            sleep 1
            continue

        elif [[ "$FOLDER_CHOICE" =~ ^[Nn]$ ]]; then
            read -rp "Enter new folder name [$DEFAULT_DIR]: " NEW_FOLDER
            NEW_FOLDER="${NEW_FOLDER:-$DEFAULT_DIR}"
            SERVER_DIR="$SERVER_ROOT/$NEW_FOLDER"

        elif [[ "$FOLDER_CHOICE" =~ ^[0-9]+$ ]] &&
             [ "$FOLDER_CHOICE" -ge 1 ] &&
             [ "$FOLDER_CHOICE" -le "${#SERVER_FOLDERS[@]}" ]; then
            SERVER_DIR="${SERVER_FOLDERS[$((FOLDER_CHOICE-1))]}"

        else
            err "Invalid folder choice."
            sleep 1
            continue
        fi
    fi

    SERVER_NAME="$(basename "$SERVER_DIR")"

    # ── Show selection ──────────────────────────────────────
    echo ""
    ok "Version : $VERSION_LABEL"
    ok "Folder  : $SERVER_DIR"
    echo ""

    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR"

    BACKUP_FILE=""

    # ── Backup worlds and configuration ──────────────────────
    if [ -d "worlds" ]; then
        TS="$(date +%Y%m%d_%H%M%S)"
        BACKUP_FILE="backup_${TS}.tar.gz"
        BACKUP_ITEMS=(worlds)

        for file in \
            server.properties \
            permissions.json \
            allowlist.json \
            valid_known_packs.json
        do
            [ -f "$file" ] && BACKUP_ITEMS+=("$file")
        done

        info "Backing up worlds and configuration..."

        if ! tar -czf "$BACKUP_FILE" "${BACKUP_ITEMS[@]}"; then
            err "Backup failed. Update aborted."
        fi

        ok "Backup saved: $SERVER_DIR/$BACKUP_FILE"
    else
        warn "No 'worlds' directory found - skipping backup."
    fi

    # ── Download ─────────────────────────────────────────────
    echo ""
    info "Downloading $VERSION_LABEL..."

    rm -f "$SERVER_ZIP"

    wget -q --show-progress "$DOWNLOAD_URL" -O "$SERVER_ZIP" ||
        err "Download failed."

    # ── Extract ──────────────────────────────────────────────
    echo ""
    info "Extracting server files..."

    unzip -o "$SERVER_ZIP" ||
        err "Extraction failed."

    rm -f "$SERVER_ZIP"

    # ── Check server ─────────────────────────────────────────
    [ -f "bedrock_server" ] ||
        err "bedrock_server not found after extraction."

    chmod +x bedrock_server
    ok "bedrock_server marked executable."

    # ── Restore configuration after update ───────────────────
    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        info "Restoring server configuration..."

        for file in \
            server.properties \
            permissions.json \
            allowlist.json \
            valid_known_packs.json
        do
            if tar -xzf "$BACKUP_FILE" -- "$file" 2>/dev/null; then
                ok "Restored $file"
            fi
        done

        ok "Server configuration restored."
    fi

    # ── Store installed version ─────────────────────────────
    INSTALLED_VERSION=""

    if [[ "$DOWNLOAD_URL" =~ bedrock-server-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.zip ]]; then
        INSTALLED_VERSION="${BASH_REMATCH[1]}"
    elif [[ "$DOWNLOAD_URL" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        INSTALLED_VERSION="${BASH_REMATCH[1]}"
    fi

    if [ "$VERSION_CHOICE" = "3" ]; then
        INSTALLED_VERSION="$CUSTOM_VERSION"
    fi

    printf '%s\n' "${INSTALLED_VERSION:-$VERSION_LABEL}" > "$VERSION_FILE_NAME"

    ok "Installed version: $(cat "$VERSION_FILE_NAME")"

    # ── Complete ─────────────────────────────────────────────
    echo ""
    echo -e "${GREEN}${BOLD}✓ Install/update complete!${RESET}"
    echo ""
    echo -e "  ${BOLD}Version:${RESET} $(cat "$VERSION_FILE_NAME")"
    echo -e "  ${BOLD}Folder :${RESET} $SERVER_DIR"
    [ -n "$BACKUP_FILE" ] &&
        echo -e "  ${BOLD}Backup :${RESET} $SERVER_DIR/$BACKUP_FILE"
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