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

SERVER_ROOT="$HOME/Bedrock Server/Data"
BACKUP_ROOT="$HOME/Bedrock Server/Backups"
SERVER_FOLDERS=()

if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run inside Debian as root."
fi

if [ ! -d "$SERVER_ROOT" ]; then
    err "Bedrock Server Data directory not found: $SERVER_ROOT"
fi

mkdir -p "$BACKUP_ROOT"

for folder in "$SERVER_ROOT"/*/; do
    [ -d "$folder" ] && SERVER_FOLDERS+=("${folder%/}")
done

if [ ${#SERVER_FOLDERS[@]} -eq 0 ]; then
    err "No server folders found in $SERVER_ROOT."
fi

echo -e "${BOLD}Available servers:${RESET}"
echo ""

INDEX=1

for folder in "${SERVER_FOLDERS[@]}"; do
    NAME="$(basename "$folder")"
    VERSION_INFO=""

    if [ -f "$folder/release-notes.txt" ]; then
        VERSION_INFO="$(head -n1 "$folder/release-notes.txt" 2>/dev/null || true)"
    fi

    if [ -n "$VERSION_INFO" ]; then
        echo -e "  ${CYAN}${INDEX})${RESET} $NAME  ($VERSION_INFO)"
    else
        echo -e "  ${CYAN}${INDEX})${RESET} $NAME"
    fi

    INDEX=$((INDEX + 1))
done

echo ""

if [ ${#SERVER_FOLDERS[@]} -eq 1 ]; then
    read -rp "Enter choice [1]: " FOLDER_CHOICE
    FOLDER_CHOICE="${FOLDER_CHOICE:-1}"
else
    read -rp "Enter choice [1-${#SERVER_FOLDERS[@]}]: " FOLDER_CHOICE
fi

if ! [[ "$FOLDER_CHOICE" =~ ^[0-9]+$ ]] ||
   [ "$FOLDER_CHOICE" -lt 1 ] ||
   [ "$FOLDER_CHOICE" -gt ${#SERVER_FOLDERS[@]} ]; then
    err "Invalid choice."
fi

SERVER_DIR="${SERVER_FOLDERS[$((FOLDER_CHOICE - 1))]}"
SERVER_NAME="$(basename "$SERVER_DIR")"

if [ ! -d "$SERVER_DIR" ]; then
    err "Server directory not found: $SERVER_DIR"
fi

BACKUP_DIR="$BACKUP_ROOT/$SERVER_NAME"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/${SERVER_NAME}_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo ""
ok "Server  : $SERVER_NAME"
ok "Source  : $SERVER_DIR"
ok "Backup  : $BACKUP_FILE"
echo ""

warn "The server should be stopped before creating a backup."
echo ""
read -rp "Continue with backup? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo ""
    warn "Backup cancelled."
    exit 0
fi

echo ""
info "Creating backup..."
echo ""

tar -czf "$BACKUP_FILE" -C "$SERVER_ROOT" "$SERVER_NAME" \
    || err "Backup failed."

if [ ! -f "$BACKUP_FILE" ]; then
    err "Backup file was not created."
fi

BACKUP_SIZE="$(du -h "$BACKUP_FILE" | cut -f1)"

echo ""
ok "Backup created successfully."
echo ""
echo -e "  ${BOLD}Server:${RESET} $SERVER_NAME"
echo -e "  ${BOLD}File  :${RESET} $BACKUP_FILE"
echo -e "  ${BOLD}Size  :${RESET} $BACKUP_SIZE"
echo ""