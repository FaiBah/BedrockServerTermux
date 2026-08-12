#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; }

SETUP_URL="https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")"

show_title(){
    clear
    echo ""
    echo -e "${BOLD}${CYAN}Update Manager${RESET}"
    echo "--------------"
    echo ""
}

if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run inside Debian as root."
    exit 1
fi

command -v curl >/dev/null 2>&1 ||
    { err "curl is not installed."; exit 1; }

show_title

echo -e "${BOLD}Manager Path:${RESET} $SERVER_ROOT"
echo ""
echo "This will update the manager and menu files."
echo "Servers/ will not be deleted."
echo "Backups/ will not be deleted."
echo ""

read -rp "Continue with manager update? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    info "Update cancelled."
    exit 0
fi

echo ""
info "Updating manager..."

if curl -fsSL "$SETUP_URL" | bash; then
    echo ""
    ok "Manager update complete."
    info "Run 'bds' again to start the updated manager."
else
    echo ""
    err "Manager update failed."
    info "Please check your internet connection and try again."
fi

echo ""