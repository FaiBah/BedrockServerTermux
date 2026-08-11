#!/bin/bash
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

TITLE="Delete Server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")/Servers"
VERSION_FILE="version.txt"

# ── Show title ──────────────────────────────────────────────
show_title(){
    clear
    echo ""
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo -e "${BOLD}             $TITLE${RESET}"
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo ""
}

# ── Check environment ───────────────────────────────────────
[ "$(id -u)" -eq 0 ] ||
    { err "This script must be run inside Debian as root."; exit 1; }

[ -d "$SERVER_ROOT" ] ||
    { err "Bedrock Server Servers directory not found: $SERVER_ROOT"; exit 1; }

# ── Server selection ────────────────────────────────────────
while true; do
    SERVER_FOLDERS=()

    for folder in "$SERVER_ROOT"/*; do
        [ -d "$folder" ] && SERVER_FOLDERS+=("$folder")
    done

    show_title

    if [ "${#SERVER_FOLDERS[@]}" -eq 0 ]; then
        warn "No server folders found."
        exit 0
    fi

    echo -e "${BOLD}Available servers:${RESET}"
    echo ""

    for i in "${!SERVER_FOLDERS[@]}"; do
        folder="${SERVER_FOLDERS[$i]}"
        name="$(basename "$folder")"
        version=""

        [ -f "$folder/$VERSION_FILE" ] &&
            version="$(head -n1 "$folder/$VERSION_FILE" 2>/dev/null || true)"

        if [ -n "$version" ]; then
            echo -e "  ${CYAN}$((i + 1)))${RESET} $name ${GREEN}(v$version)${RESET}"
        else
            echo -e "  ${CYAN}$((i + 1)))${RESET} $name ${YELLOW}(version unknown)${RESET}"
        fi
    done

    echo -e "  ${CYAN}0)${RESET} Back"
    echo ""

    read -rp "Enter choice [0-${#SERVER_FOLDERS[@]}]: " choice

    # ── Handle menu choice ──────────────────────────────────
    if [ "$choice" = "0" ]; then
        info "Back to manage menu..."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
       [ "$choice" -lt 1 ] ||
       [ "$choice" -gt "${#SERVER_FOLDERS[@]}" ]; then
        err "Invalid choice."
        sleep 1
        continue
    fi

    SERVER_DIR="${SERVER_FOLDERS[$((choice - 1))]}"
    SERVER_NAME="$(basename "$SERVER_DIR")"
    SERVER_VERSION="Unknown"

    # ── Read server version ─────────────────────────────────
    if [ -f "$SERVER_DIR/$VERSION_FILE" ]; then
        VERSION="$(head -n1 "$SERVER_DIR/$VERSION_FILE" 2>/dev/null || true)"
        [ -n "$VERSION" ] && SERVER_VERSION="$VERSION"
    fi

    # ── Confirm deletion ────────────────────────────────────
    echo ""
    warn "Permanently delete:"
    echo -e "  ${BOLD}Server :${RESET} $SERVER_NAME"
    echo -e "  ${BOLD}Version:${RESET} $SERVER_VERSION"
    echo -e "  ${BOLD}Path   :${RESET} $SERVER_DIR"
    echo ""
    warn "All worlds and server data will be deleted."
    echo ""

    read -rp "Type 'DELETE' to confirm: " confirm

    if [ "$confirm" != "DELETE" ]; then
        warn "Deletion cancelled."
        sleep 1
        continue
    fi

    # ── Delete server ───────────────────────────────────────
    echo ""
    info "Deleting server: $SERVER_NAME..."

    rm -rf -- "$SERVER_DIR"

    if [ -d "$SERVER_DIR" ]; then
        err "Failed to delete server."
    else
        ok "Server deleted: $SERVER_NAME"
    fi

    sleep 2
done