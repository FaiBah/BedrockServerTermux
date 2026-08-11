#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; }

TITLE="Bedrock Server Manager"
SHOW_TITLE=true
CLEAR_SCREEN=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_DIR="$SCRIPT_DIR/menu"

# Show manager title
show_title(){
    $CLEAR_SCREEN && clear

    $SHOW_TITLE || return

    echo ""
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo -e "${BOLD}        $TITLE${RESET}"
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo ""
}

# Check root
[ "$(id -u)" -eq 0 ] ||
    { err "This script must be run inside Debian as root."; exit 1; }

# Main menu
while true; do
    show_title

    echo -e "  ${CYAN}1)${RESET} Run server"
    echo -e "  ${CYAN}2)${RESET} Install / Update server"
    echo -e "  ${CYAN}3)${RESET} Backup server"
    echo -e "  ${CYAN}4)${RESET} Rename server"
    echo -e "  ${CYAN}5)${RESET} Delete server"
    echo -e "  ${CYAN}6)${RESET} Update manager"
    echo -e "  ${CYAN}0)${RESET} Exit"
    echo ""

    read -rp "Enter choice [0-5]: " choice

    case "$choice" in
        1) bash "$MENU_DIR/run.sh" ;;
        2) bash "$MENU_DIR/install.sh" ;;
        3) bash "$MENU_DIR/backup.sh" ;;
        4) bash "$MENU_DIR/rename.sh" ;;
        5) bash "$MENU_DIR/delete.sh" ;;
        6) bash "$MENU_DIR/update.sh" ;;
        0)
            info "Goodbye."
            exit 0
            ;;
        *)
            err "Invalid choice."
            sleep 1
            continue
            ;;
    esac

    echo ""
    read -rp "Press Enter to return to the manager..."
done