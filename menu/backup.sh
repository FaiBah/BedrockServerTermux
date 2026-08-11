#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; }
pause(){ sleep "${1:-1}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")/Servers"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")/Backups"
VERSION_FILE="version.txt"

title(){
    clear
    echo ""
    echo -e "${BOLD}${CYAN}Backup Server${RESET}"
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

mkdir -p "$BACKUP_ROOT"

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
        pause
        continue
    fi

    SERVER_DIR="${SERVERS[$((choice - 1))]}"
    SERVER_NAME="$(basename "$SERVER_DIR")"
    SERVER_VERSION="Unknown"

    if [ -f "$SERVER_DIR/$VERSION_FILE" ]; then
        version="$(head -n1 "$SERVER_DIR/$VERSION_FILE" 2>/dev/null || true)"
        [ -n "$version" ] && SERVER_VERSION="$version"
    fi

    BACKUP_DIR="$BACKUP_ROOT/$SERVER_NAME"
    mkdir -p "$BACKUP_DIR"

    while true; do
        title

        echo -e "${BOLD}Server:${RESET}  $SERVER_NAME"
        echo -e "${BOLD}Version:${RESET} $SERVER_VERSION"
        echo ""
        echo -e "${BOLD}Backup Type:${RESET}"
        echo ""
        echo "1) Full Server"
        echo "2) World Data Only"
        echo "3) Server Configuration"
        echo "0) Back"
        echo ""

        read -rp "Select an option [0-3]: " type

        case "$type" in
            0)
                info "Back to server selection..."
                pause
                break
                ;;

            1)
                LABEL="Full Server"
                FILE="${SERVER_NAME}_full_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE" -C "$SERVER_DIR" .)
                ;;

            2)
                LABEL="World Data Only"

                if [ ! -d "$SERVER_DIR/worlds" ]; then
                    warn "No worlds directory found."
                    pause
                    continue
                fi

                FILE="${SERVER_NAME}_worlds_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE" -C "$SERVER_DIR" worlds)
                ;;

            3)
                LABEL="Server Configuration"
                FILES=()

                for file in \
                    server.properties \
                    permissions.json \
                    allowlist.json \
                    valid_known_packs.json
                do
                    [ -f "$SERVER_DIR/$file" ] && FILES+=("$file")
                done

                if [ "${#FILES[@]}" -eq 0 ]; then
                    warn "No server configuration files found."
                    pause
                    continue
                fi

                FILE="${SERVER_NAME}_config_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE" -C "$SERVER_DIR" "${FILES[@]}")
                ;;

            *)
                err "Invalid option."
                pause
                continue
                ;;
        esac

        echo ""
        echo -e "${BOLD}Server :${RESET} $SERVER_NAME"
        echo -e "${BOLD}Version:${RESET} $SERVER_VERSION"
        echo -e "${BOLD}Type   :${RESET} $LABEL"
        echo ""

        read -rp "Continue with backup? [y/N]: " confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Backup cancelled."
            pause
            continue
        fi

        echo ""
        info "Creating backup..."

        BACKUP_FILE="$BACKUP_DIR/$FILE"

        if "${COMMAND[@]}"; then
            SIZE="$(du -h "$BACKUP_FILE" | cut -f1)"

            echo ""
            ok "Backup created successfully."
            echo ""
            echo -e "  ${BOLD}Server :${RESET} $SERVER_NAME"
            echo -e "  ${BOLD}Version:${RESET} $SERVER_VERSION"
            echo -e "  ${BOLD}Type   :${RESET} $LABEL"
            echo -e "  ${BOLD}File   :${RESET} $BACKUP_FILE"
            echo -e "  ${BOLD}Size   :${RESET} $SIZE"
        else
            err "Backup failed."
        fi

        echo ""
        pause 2
    done
done