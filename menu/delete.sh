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
    echo -e "${BOLD}${CYAN}Delete Server${RESET}"
    echo "-------------"
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

    if [ "$choice" = "0" ]; then
        info "Back to manage menu..."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
       [ "$choice" -lt 1 ] ||
       [ "$choice" -gt "${#SERVERS[@]}" ]; then
        err "Invalid option."
        sleep 1
        continue
    fi

    SERVER_DIR="${SERVERS[$((choice - 1))]}"
    SERVER_NAME="$(basename "$SERVER_DIR")"
    SERVER_VERSION="Unknown"

    if [ -f "$SERVER_DIR/$VERSION_FILE" ]; then
        VERSION="$(head -n1 "$SERVER_DIR/$VERSION_FILE" 2>/dev/null || true)"
        [ -n "$VERSION" ] && SERVER_VERSION="$VERSION"
    fi

    echo ""
    warn "Permanently delete this server?"
    echo ""
    echo "Server : $SERVER_NAME"
    echo "Version: $SERVER_VERSION"
    echo "Path   : $SERVER_DIR"
    echo ""
    warn "All worlds and server data will be deleted."
    echo ""

    read -rp "Type 'DELETE' to confirm: " confirm

    if [ "$confirm" != "DELETE" ]; then
        info "Deletion cancelled."
        sleep 1
        continue
    fi

    echo ""
    info "Deleting server..."

    if rm -rf -- "$SERVER_DIR"; then
        ok "Server deleted: $SERVER_NAME"
    else
        err "Failed to delete server."
    fi

    sleep 2
done