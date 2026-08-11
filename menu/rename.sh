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

TITLE="Rename Server"
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
    OLD_NAME="$(basename "$SERVER_DIR")"
    SERVER_VERSION="Unknown"

    # ── Read server version ─────────────────────────────────
    if [ -f "$SERVER_DIR/$VERSION_FILE" ]; then
        VERSION="$(head -n1 "$SERVER_DIR/$VERSION_FILE" 2>/dev/null || true)"
        [ -n "$VERSION" ] && SERVER_VERSION="$VERSION"
    fi

    echo ""
    echo -e "${BOLD}Current server:${RESET} $OLD_NAME"
    echo -e "${BOLD}Version:${RESET} $SERVER_VERSION"
    echo ""

    # ── Enter new name ──────────────────────────────────────
    read -rp "Enter new server name: " NEW_NAME

    if [ -z "$NEW_NAME" ]; then
        err "Server name cannot be empty."
        sleep 1
        continue
    fi

    if [[ "$NEW_NAME" == "." || "$NEW_NAME" == ".." || "$NEW_NAME" == */* ]]; then
        err "Invalid server name."
        sleep 1
        continue
    fi

    if [ "$NEW_NAME" = "$OLD_NAME" ]; then
        warn "New name is the same as the current name."
        sleep 1
        continue
    fi

    NEW_DIR="$SERVER_ROOT/$NEW_NAME"

    if [ -e "$NEW_DIR" ]; then
        err "A server named \"$NEW_NAME\" already exists."
        sleep 1
        continue
    fi

    # ── Confirm rename ──────────────────────────────────────
    echo ""
    warn "Rename server:"
    echo -e "  ${BOLD}$OLD_NAME${RESET} ${CYAN}→${RESET} ${BOLD}$NEW_NAME${RESET}"
    echo -e "  ${BOLD}Version:${RESET} $SERVER_VERSION"
    echo ""

    read -rp "Continue with rename? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warn "Rename cancelled."
        sleep 1
        continue
    fi

    # ── Rename server ───────────────────────────────────────
    echo ""
    info "Renaming server..."

    if mv -- "$SERVER_DIR" "$NEW_DIR"; then
        ok "Server renamed successfully."
        echo ""
        echo -e "  ${BOLD}Old name:${RESET} $OLD_NAME"
        echo -e "  ${BOLD}New name:${RESET} $NEW_NAME"
        echo -e "  ${BOLD}Version :${RESET} $SERVER_VERSION"
    else
        err "Failed to rename server."
    fi

    sleep 2
done