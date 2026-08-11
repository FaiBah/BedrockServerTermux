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

TITLE="Run Server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")/Servers"
VERSION_FILE="version.txt"

# ── Show title ──────────────────────────────────────────────
show_title(){
    clear
    echo ""
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo -e "${BOLD}              $TITLE${RESET}"
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

    # ── Check server binary ─────────────────────────────────
    if [ ! -f "$SERVER_DIR/bedrock_server" ]; then
        err "bedrock_server binary not found in $SERVER_DIR."
        sleep 2
        continue
    fi

    chmod +x "$SERVER_DIR/bedrock_server"
    cd "$SERVER_DIR"

    echo ""
    ok "Server : $SERVER_NAME"
    ok "Version: $SERVER_VERSION"
    echo -e "  Press ${CYAN}Ctrl+C${RESET} to stop."
    echo ""

    # ── Configure Box64 ─────────────────────────────────────
    PAGESIZE="$(getconf PAGESIZE 2>/dev/null || echo 4096)"
    info "Detected page size: ${PAGESIZE} bytes"

    _run_server(){
        export LD_LIBRARY_PATH=".:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export BOX64_LOG=0
        export BOX64_MMAP32=1
        export BOX64_NOSIGSEGV=1
        export BOX64_PAGESIZE="$PAGESIZE"
        export BOX64_DYNAREC_WAIT=1
        export BOX64_DYNAREC_STRONGMEM=1

        box64 bedrock_server 2>&1 | grep -v 'Box64 with Dynarec'
    }

    # ── Run server with automatic restart ───────────────────
    USER_STOP=false
    trap 'USER_STOP=true' SIGINT

    while true; do
        USER_STOP=false

        info "Launching bedrock_server..."
        _run_server || true
        EXIT_CODE=${PIPESTATUS[0]:-$?}

        if [ "$USER_STOP" = true ]; then
            echo ""
            warn "Server stopped by user."
            break
        fi

        if [ "$EXIT_CODE" -eq 0 ]; then
            echo ""
            warn "Server stopped cleanly."
            break
        fi

        echo ""
        err "Server crashed (exit code: $EXIT_CODE)."
        echo -e "${CYAN}[*]${RESET} Restarting in 5 seconds... (Ctrl+C to abort)"
        sleep 5
    done

    trap - SIGINT

    # ── Return to server list ───────────────────────────────
    echo ""
    info "Returning to server list..."
    sleep 1
done