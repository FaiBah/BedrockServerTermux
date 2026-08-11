#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; exit 1; }

TITLE="Update Manager"
SETUP_URL="https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup.sh"

# ── Get manager path ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")"

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
    err "This script must be run inside Debian as root."

command -v curl >/dev/null 2>&1 ||
    err "curl is not installed."

# ── Confirm update ──────────────────────────────────────────
show_title

echo -e "${BOLD}Manager path:${RESET} $SERVER_ROOT"
echo ""

echo -e "${CYAN}This will update the manager and menu files.${RESET}"
echo -e "  ${GREEN}Servers/${RESET} will not be deleted."
echo -e "  ${GREEN}Backups/${RESET} will not be deleted."
echo ""

read -rp "Continue with manager update? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    info "Update cancelled."
    exit 0
fi

# ── Download and run setup ─────────────────────────────────
echo ""
info "Updating manager..."

if ! curl -fsSL "$SETUP_URL" | bash; then
    err "Manager update failed."
fi

# ── Complete ────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ Manager update complete!${RESET}"
echo ""
ok "Latest manager installed."
echo ""
info "Please run 'bds' again to start the updated manager."
echo ""

exit 0