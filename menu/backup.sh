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
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SERVER_ROOT="$PROJECT_ROOT/Servers"
BACKUP_ROOT="$PROJECT_ROOT/Backups"
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

if [ ! -d "$SERVER_ROOT" ]; then
    err "Servers directory not found: $SERVER_ROOT"
    exit 1
fi

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
        echo -e "  ${CYAN}1)${RESET} Full Server"
        echo -e "  ${CYAN}2)${RESET} Worlds Only"
        echo -e "  ${CYAN}3)${RESET} Configuration"
        echo -e "  ${CYAN}0)${RESET} Back"
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
                FILE="backup_full_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE.tmp" -C "$SERVER_DIR" .)
                ;;

            2)
                LABEL="Worlds Only"

                if [ ! -d "$SERVER_DIR/worlds" ]; then
                    warn "No worlds directory found."
                    pause
                    continue
                fi

                FILE="backup_worlds_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE.tmp" -C "$SERVER_DIR" worlds)
                ;;

            3)
                LABEL="Configuration"
                FILES=()

                for item in \
                    config \
                    allowlist.json \
                    permissions.json \
                    server.properties
                do
                    if [ -e "$SERVER_DIR/$item" ]; then
                        FILES+=("$item")
                    fi
                done

                if [ "${#FILES[@]}" -eq 0 ]; then
                    warn "No configuration files or folders found."
                    pause
                    continue
                fi

                FILE="backup_config_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE.tmp" -C "$SERVER_DIR" "${FILES[@]}")
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
        TEMP_FILE="$BACKUP_FILE.tmp"

        rm -f "$TEMP_FILE"

        if "${COMMAND[@]}"; then
            if mv "$TEMP_FILE" "$BACKUP_FILE"; then
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
                rm -f "$TEMP_FILE"
                err "Failed to finalize backup."
            fi
        else
            rm -f "$TEMP_FILE"
            err "Backup failed."
        fi

        echo ""
        pause 2
    done
done