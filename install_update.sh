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
err()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }

API_URL="https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"
REPO="https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main"
SERVER_ZIP="bedrock_server_latest.zip"
SERVER_ROOT="$HOME/Bedrock Server"
PACKAGES="curl jq unzip wget tar rsync"

# Check Debian
if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run inside Debian as root."
fi

ok "Debian environment detected."

# Update package lists
info "Updating package lists..."

apt update -y ||
    err "Failed to update package lists."

# Check dependencies
info "Checking dependencies..."

MISSING=""

for pkg in $PACKAGES; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg is installed."
    else
        MISSING="$MISSING $pkg"
    fi
done

# Install missing dependencies
if [ -n "$MISSING" ]; then
    info "Installing missing packages:$MISSING"

    apt install -y $MISSING ||
        err "Failed to install dependencies."
else
    ok "All dependencies are installed."
fi

# Update dependencies
info "Updating installed dependencies..."

apt install --only-upgrade -y $PACKAGES ||
    err "Failed to update dependencies."

mkdir -p "$SERVER_ROOT"

# Find all server folders
SERVER_FOLDERS=()

for folder in "$SERVER_ROOT"/*/; do
    [ -d "$folder" ] && SERVER_FOLDERS+=("${folder%/}")
done

if [ ${#SERVER_FOLDERS[@]} -eq 0 ]; then
    warn "No existing server folders found. A new one will be created."
fi

# Select version
echo ""
echo -e "${BOLD}Select version to install:${RESET}"
echo ""
echo -e "  ${CYAN}1)${RESET} Latest Stable       ${GREEN}(Recommended)${RESET}"
echo -e "  ${CYAN}2)${RESET} Latest Preview/Beta"
echo -e "  ${CYAN}3)${RESET} Specific version    (e.g. 1.26.10.20)"
echo ""

read -rp "Enter choice [1/2/3]: " VERSION_CHOICE

case "$VERSION_CHOICE" in
    1)
        info "Fetching latest stable URL..."

        DOWNLOAD_URL="$(
            curl -fsSL "$API_URL" |
            jq -r '.result.links[] |
            select(.downloadType=="serverBedrockLinux") |
            .downloadUrl'
        )"

        DEFAULT_DIR="server"
        VERSION_LABEL="Latest Stable"
        ;;

    2)
        info "Fetching latest preview URL..."

        DOWNLOAD_URL="$(
            curl -fsSL "$API_URL" |
            jq -r '.result.links[] |
            select(.downloadType=="serverBedrockPreviewLinux") |
            .downloadUrl'
        )"

        DEFAULT_DIR="server_preview"
        VERSION_LABEL="Latest Preview"
        ;;

    3)
        echo ""
        read -rp "Enter version number (e.g. 1.26.10.4): " CUSTOM_VERSION

        DOWNLOAD_URL="https://www.minecraft.net/bedrockdedicatedserver/bin-linux/bedrock-server-${CUSTOM_VERSION}.zip"
        DEFAULT_DIR="server_${CUSTOM_VERSION}"
        VERSION_LABEL="$CUSTOM_VERSION"

        warn "Older versions may not work on ARM."
        ;;

    *)
        err "Invalid choice."
        ;;
esac

if [ -z "${DOWNLOAD_URL:-}" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    err "Could not resolve download URL."
fi

# Select folder
echo ""
echo -e "${BOLD}Select target folder:${RESET}"
echo ""

INDEX=1

for folder in "${SERVER_FOLDERS[@]}"; do
    NAME="$(basename "$folder")"

    if [ "$NAME" = "$DEFAULT_DIR" ]; then
        echo -e "  ${CYAN}${INDEX})${RESET} $NAME ${GREEN}(default for this version)${RESET}"
    else
        echo -e "  ${CYAN}${INDEX})${RESET} $NAME"
    fi

    INDEX=$((INDEX + 1))
done

echo -e "  ${CYAN}N)${RESET} Create a new folder"
echo ""

if [ ${#SERVER_FOLDERS[@]} -eq 0 ]; then
    read -rp "Enter folder name [${DEFAULT_DIR}]: " NEW_FOLDER
    SERVER_DIR="$SERVER_ROOT/${NEW_FOLDER:-$DEFAULT_DIR}"
else
    read -rp "Enter choice: " FOLDER_CHOICE

    if [[ "$FOLDER_CHOICE" =~ ^[Nn]$ ]]; then
        read -rp "Enter new folder name [${DEFAULT_DIR}]: " NEW_FOLDER
        SERVER_DIR="$SERVER_ROOT/${NEW_FOLDER:-$DEFAULT_DIR}"

    elif [[ "$FOLDER_CHOICE" =~ ^[0-9]+$ ]] &&
         [ "$FOLDER_CHOICE" -ge 1 ] &&
         [ "$FOLDER_CHOICE" -le ${#SERVER_FOLDERS[@]} ]; then

        SERVER_DIR="${SERVER_FOLDERS[$((FOLDER_CHOICE - 1))]}"

    else
        err "Invalid folder choice."
    fi
fi

echo ""
ok "Version : $VERSION_LABEL"
ok "Folder  : $SERVER_DIR"
echo ""

mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"

# Backup worlds
if [ -d "worlds" ]; then
    TS="$(date +%Y%m%d_%H%M%S)"
    BACKUP_FILE="worlds_backup_${TS}.tar.gz"

    info "Backing up worlds → $BACKUP_FILE ..."

    tar -czf "$BACKUP_FILE" worlds ||
        err "Backup failed. Aborting to protect your worlds."

    ok "Backup saved: $BACKUP_FILE"
else
    warn "No 'worlds' directory found — skipping backup."
fi

echo ""

# Download server
info "Downloading $VERSION_LABEL..."

rm -f "$SERVER_ZIP"

wget -q --show-progress "$DOWNLOAD_URL" \
    -O "$SERVER_ZIP" ||
    err "Download failed."

# Extract server
info "Extracting server files..."

unzip -o "$SERVER_ZIP" ||
    err "Extraction failed."

rm -f "$SERVER_ZIP"

# Check server binary
if [ -f "bedrock_server" ]; then
    chmod +x bedrock_server
    ok "bedrock_server marked executable."
else
    err "bedrock_server not found after extraction."
fi

# Update run.sh
cd "$SERVER_ROOT"

info "Updating run.sh..."

wget -q "$REPO/run.sh" -O run.sh ||
    err "Failed to update run.sh."

chmod +x run.sh

echo ""
echo -e "${GREEN}${BOLD}✓ Install/update complete!${RESET}"
echo ""
echo -e "  ${BOLD}Version:${RESET} $VERSION_LABEL"
echo -e "  ${BOLD}Folder :${RESET} $SERVER_DIR"
echo -e "  ${BOLD}Worlds :${RESET} Backed up (if present)"
echo ""
echo -e "  ${BOLD}Start server:${RESET}"
echo -e "  ${CYAN}cd \"\$HOME/Bedrock Server\" && ./run.sh${RESET}"
echo ""

if [ "$VERSION_CHOICE" = "2" ]; then
    warn "Preview/Beta: players need Minecraft Preview client to connect."
fi

if [ "$VERSION_CHOICE" = "3" ]; then
    warn "If the server crashes immediately, this version may be incompatible with your device."
    warn "Run ./install_update.sh again and choose option 1 to revert to latest stable."
fi