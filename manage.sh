#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

err()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_DIR="$SCRIPT_DIR/menu"

if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run inside Debian as root."
fi

echo -e "${BOLD}Bedrock Server Manager${RESET}"
echo ""
echo -e "  ${CYAN}1)${RESET} Install / Update server"
echo -e "  ${CYAN}2)${RESET} Run a server"
echo -e "  ${CYAN}3)${RESET} Backup server"
echo -e "  ${CYAN}4)${RESET} Delete server"
echo ""

read -rp "Enter choice [1-4]: " MENU_CHOICE

case "$MENU_CHOICE" in
    1)
        bash "$MENU_DIR/install.sh"
        ;;
    2)
        bash "$MENU_DIR/run.sh"
        ;;
    3)
        bash "$MENU_DIR/backup.sh"
        ;;
    4)
        bash "$MENU_DIR/delete.sh"
        ;;
    *)
        err "Invalid choice."
        ;;
esac