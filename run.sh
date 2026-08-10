#!/usr/bin/env bash
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

USER_STOP=false
trap 'USER_STOP=true' SIGINT

SERVER_ROOT="$HOME/Bedrock Server"
SERVER_FOLDERS=()

# Check Bedrock Server directory
if [ ! -d "$SERVER_ROOT" ]; then
    err "Bedrock Server directory not found."
fi

# Find all directories inside Bedrock Server
for folder in "$SERVER_ROOT"/*/; do
    [ -d "$folder" ] && SERVER_FOLDERS+=("${folder%/}")
done

if [ ${#SERVER_FOLDERS[@]} -eq 0 ]; then
    err "No server folders found in $SERVER_ROOT. Run install_update.sh first."
fi

# Show server list
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

# Select server
if [ ${#SERVER_FOLDERS[@]} -eq 1 ]; then
    read -rp "Enter choice [1]: " FOLDER_CHOICE
else
    read -rp "Enter choice [1-${#SERVER_FOLDERS[@]}]: " FOLDER_CHOICE
fi

if ! [[ "$FOLDER_CHOICE" =~ ^[0-9]+$ ]] ||
   [ "$FOLDER_CHOICE" -lt 1 ] ||
   [ "$FOLDER_CHOICE" -gt ${#SERVER_FOLDERS[@]} ]; then
    err "Invalid choice."
fi

SERVER_DIR="${SERVER_FOLDERS[$((FOLDER_CHOICE - 1))]}"

# Check server binary
if [ ! -f "$SERVER_DIR/bedrock_server" ]; then
    err "bedrock_server binary not found in $SERVER_DIR."
fi

chmod +x "$SERVER_DIR/bedrock_server"

echo ""
ok "Starting: $(basename "$SERVER_DIR")"
echo -e "  Press ${CYAN}Ctrl+C${RESET} to stop."
echo ""

cd "$SERVER_DIR"

PAGESIZE="$(getconf PAGESIZE 2>/dev/null || echo 4096)"

info "Detected page size: ${PAGESIZE} bytes"

_run_server() {
    export LD_LIBRARY_PATH=".:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export BOX64_LOG=0
    export BOX64_MMAP32=1
    export BOX64_NOSIGSEGV=1
    export BOX64_PAGESIZE="${PAGESIZE}"
    export BOX64_DYNAREC_WAIT=1
    export BOX64_DYNAREC_STRONGMEM=1

    box64 bedrock_server 2>&1 |
        grep -v 'Box64 with Dynarec'
}

# Auto restart
while true; do
    USER_STOP=false

    info "Launching bedrock_server..."

    _run_server || true

    EXIT_CODE=${PIPESTATUS[0]:-$?}

    if [[ "$USER_STOP" == true ]]; then
        echo ""
        warn "Server stopped by user."
        break
    fi

    if [[ $EXIT_CODE -eq 0 ]]; then
        echo ""
        warn "Server stopped cleanly."
        break
    fi

    echo ""
    echo -e "${RED}[✗]${RESET} Server crashed (exit code: $EXIT_CODE)."
    echo -e "${CYAN}[*]${RESET} Restarting in 5 seconds... (Ctrl+C to abort)"

    sleep 5
done