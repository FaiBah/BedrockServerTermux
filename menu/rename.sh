#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")/Servers"
VERSION_FILE="version.txt"

title(){
    clear
    echo ""
    echo -e "${BOLD}${CYAN}Rename Server${RESET}"
    echo "-------------"
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

while true; do
    SERVERS=()

    for dir in "$SERVER_ROOT"/*; do
        [ -d "$dir" ] && SERVERS+=("$dir")
    done

    title

    if [ "${#SERVERS[@]}" -eq 0 ]; then
        warn "No servers found."
        exit 0
    fi

    echo -e "${BOLD}Available Servers:${RESET}"
    echo ""

    for i in "${!SERVERS[@]}"; do
        dir="${SERVERS[$i]}"
        name="$(basename "$dir")"
        version=""

        [ -f "$dir/$VERSION_FILE" ] &&
            version="$(head -n1 "$dir/$VERSION_FILE" 2>/dev/null || true)"

        if [ -n "$version" ]; then
            echo -e "  ${CYAN}$((i + 1)))${RESET} $name ${GREEN}(v$version)${RESET}"
        else
            echo -e "  ${CYAN}$((i + 1)))${RESET} $name ${YELLOW}(version unknown)${RESET}"
        fi
    done

    echo -e "  ${CYAN}0)${RESET} Back"
    echo ""

    read -rp "Select an option [0-${#SERVERS[@]}]: " choice

    # Back to manage.sh
    if [ "$choice" = "0" ]; then
        info "Back to manage menu..."
        exit 0
    fi

    # Invalid server selection
    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
       [ "$choice" -lt 1 ] ||
       [ "$choice" -gt "${#SERVERS[@]}" ]; then
        err "Invalid option."
        sleep 1
        continue
    fi

    SERVER_DIR="${SERVERS[$((choice - 1))]}"
    OLD_NAME="$(basename "$SERVER_DIR")"
    SERVER_VERSION="Unknown"

    if [ -f "$SERVER_DIR/$VERSION_FILE" ]; then
        version="$(head -n1 "$SERVER_DIR/$VERSION_FILE" 2>/dev/null || true)"
        [ -n "$version" ] && SERVER_VERSION="$version"
    fi

    title

    echo -e "${BOLD}Current Server:${RESET} $OLD_NAME"
    echo -e "${BOLD}Version:${RESET}        $SERVER_VERSION"
    echo ""

    read -rp "Enter new server name: " NEW_NAME

    # Empty name
    if [ -z "$NEW_NAME" ]; then
        err "Server name cannot be empty."
        sleep 1
        continue
    fi

    # Invalid name
    if [[ "$NEW_NAME" == "." ||
          "$NEW_NAME" == ".." ||
          "$NEW_NAME" == */* ]]; then
        err "Invalid server name."
        sleep 1
        continue
    fi

    # Same name
    if [ "$NEW_NAME" = "$OLD_NAME" ]; then
        warn "New name is the same as the current name."
        sleep 1
        continue
    fi

    NEW_DIR="$SERVER_ROOT/$NEW_NAME"

    # Name already exists
    if [ -e "$NEW_DIR" ]; then
        err "A server named \"$NEW_NAME\" already exists."
        sleep 1
        continue
    fi

    title

    echo -e "${BOLD}Rename Server:${RESET}"
    echo ""
    echo -e "  $OLD_NAME ${CYAN}→${RESET} $NEW_NAME"
    echo -e "  ${BOLD}Version:${RESET} $SERVER_VERSION"
    echo ""

    read -rp "Continue with rename? [y/N]: " confirm

    # Cancelled rename stays in rename.sh
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Rename cancelled."
        sleep 1
        continue
    fi

    echo ""
    info "Renaming server..."

    if mv -- "$SERVER_DIR" "$NEW_DIR"; then
        ok "Server renamed successfully."
        echo ""
        echo -e "  ${BOLD}Old Name:${RESET} $OLD_NAME"
        echo -e "  ${BOLD}New Name:${RESET} $NEW_NAME"
        echo -e "  ${BOLD}Version :${RESET} $SERVER_VERSION"
    else
        err "Failed to rename server."
    fi

    sleep 2
done