#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_DIR="$SCRIPT_DIR/menu"

err(){ echo -e "${RED}[✗]${RESET} $1"; }
pause(){ echo ""; read -rp "Press Enter to continue..."; }

if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run inside Debian as root."
    exit 1
fi

while true; do
    clear
    echo ""
    echo -e "${BOLD}${CYAN}Bedrock Server Manager${RESET}"
    echo "-----------------------"
    echo ""
    echo "1) Run Server"
    echo "2) Install / Update Server"
    echo "3) Back Up Server"
    echo "4) Rename Server"
    echo "5) Delete Server"
    echo "6) Update Manager"
    echo "0) Exit"
    echo ""

    read -rp "Select an option [0-6]: " choice
    echo ""

    case "$choice" in
        1) bash "$MENU_DIR/run.sh" ;;
        2) bash "$MENU_DIR/install.sh" ;;
        3) bash "$MENU_DIR/backup.sh" ;;
        4) bash "$MENU_DIR/rename.sh" ;;
        5) bash "$MENU_DIR/delete.sh" ;;
        6) bash "$MENU_DIR/update.sh" ;;
        0) exit 0 ;;
        *) err "Invalid option."; sleep 1; continue ;;
    esac

    pause
done