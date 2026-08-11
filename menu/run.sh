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

title(){
    clear
    echo ""
    echo -e "${BOLD}${CYAN}Run Server${RESET}"
    echo "----------"
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

        if [ -f "$dir/$VERSION_FILE" ]; then
            version="$(head -n1 "$dir/$VERSION_FILE" 2>/dev/null || true)"
        fi

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
        version="$(head -n1 "$SERVER_DIR/$VERSION_FILE" 2>/dev/null || true)"
        [ -n "$version" ] && SERVER_VERSION="$version"
    fi

    if [ ! -f "$SERVER_DIR/bedrock_server" ]; then
        err "bedrock_server binary not found."
        sleep 2
        continue
    fi

    chmod +x "$SERVER_DIR/bedrock_server"
    cd "$SERVER_DIR"

    echo ""
    echo -e "${BOLD}Server :${RESET} $SERVER_NAME"
    echo -e "${BOLD}Version:${RESET} $SERVER_VERSION"
    echo ""
    echo -e "Press ${CYAN}Ctrl+C${RESET} to stop."
    echo ""

    PAGESIZE="$(getconf PAGESIZE 2>/dev/null || echo 4096)"
    info "Page size: ${PAGESIZE} bytes"

    run_server(){
        export LD_LIBRARY_PATH=".:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export BOX64_LOG=0
        export BOX64_MMAP32=1
        export BOX64_NOSIGSEGV=1
        export BOX64_PAGESIZE="$PAGESIZE"
        export BOX64_DYNAREC_WAIT=1
        export BOX64_DYNAREC_STRONGMEM=1

        box64 bedrock_server 2>&1 | grep -v 'Box64 with Dynarec'
    }

    USER_STOP=false
    trap 'USER_STOP=true' SIGINT

    while true; do
        USER_STOP=false

        info "Starting server..."

        run_server || true
        EXIT_CODE="${PIPESTATUS[0]:-$?}"

        if [ "$USER_STOP" = true ]; then
            echo ""
            warn "Server stopped by user."
            break
        fi

        if [ "$EXIT_CODE" -eq 0 ]; then
            echo ""
            warn "Server stopped."
            break
        fi

        echo ""
        err "Server crashed (exit code: $EXIT_CODE)."
        info "Restarting in 5 seconds... (Ctrl+C to abort)"
        sleep 5
    done

    trap - SIGINT

    echo ""
    info "Returning to server list..."
    sleep 1
done