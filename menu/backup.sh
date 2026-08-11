#!/bin/bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; }

TITLE="Backup Server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_ROOT="$(dirname "$SCRIPT_DIR")/Servers"
BACKUP_ROOT="$(dirname "$SCRIPT_DIR")/Backups"
VERSION_FILE="version.txt"

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
[ "$(id -u)" -eq 0 ] || { err "This script must be run inside Debian as root."; exit 1; }
[ -d "$SERVER_ROOT" ] || { err "Servers directory not found: $SERVER_ROOT"; exit 1; }

mkdir -p "$BACKUP_ROOT"

# ── Server selection ────────────────────────────────────────
while true; do
    SERVER_FOLDERS=()
    for folder in "$SERVER_ROOT"/*; do
        [ -d "$folder" ] && SERVER_FOLDERS+=("$folder")
    done

    show_title

    [ "${#SERVER_FOLDERS[@]}" -gt 0 ] || { warn "No server folders found."; exit 0; }

    echo -e "${BOLD}Available servers:${RESET}"
    echo ""

    for i in "${!SERVER_FOLDERS[@]}"; do
        folder="${SERVER_FOLDERS[$i]}"
        name="$(basename "$folder")"
        version=""

        [ -f "$folder/$VERSION_FILE" ] &&
            version="$(head -n1 "$folder/$VERSION_FILE" 2>/dev/null || true)"

        [ -n "$version" ] &&
            echo -e "  ${CYAN}$((i+1)))${RESET} $name ${GREEN}(v$version)${RESET}" ||
            echo -e "  ${CYAN}$((i+1)))${RESET} $name ${YELLOW}(version unknown)${RESET}"
    done

    echo -e "  ${CYAN}0)${RESET} Back"
    echo ""

    read -rp "Enter choice [0-${#SERVER_FOLDERS[@]}]: " choice

    [ "$choice" = "0" ] && { info "Back to manage menu..."; exit 0; }

    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
       [ "$choice" -lt 1 ] ||
       [ "$choice" -gt "${#SERVER_FOLDERS[@]}" ]; then
        err "Invalid choice."
        sleep 1
        continue
    fi

    SERVER_DIR="${SERVER_FOLDERS[$((choice-1))]}"
    SERVER_NAME="$(basename "$SERVER_DIR")"
    SERVER_VERSION="Unknown"

    if [ -f "$SERVER_DIR/$VERSION_FILE" ]; then
        VERSION="$(head -n1 "$SERVER_DIR/$VERSION_FILE" 2>/dev/null || true)"
        [ -n "$VERSION" ] && SERVER_VERSION="$VERSION"
    fi

    BACKUP_DIR="$BACKUP_ROOT/$SERVER_NAME"
    mkdir -p "$BACKUP_DIR"

    # ── Backup type selection ───────────────────────────────
    while true; do
        show_title

        echo -e "${BOLD}Server :${RESET} $SERVER_NAME"
        echo -e "${BOLD}Version:${RESET} $SERVER_VERSION"
        echo ""
        echo -e "${BOLD}Select backup type:${RESET}"
        echo -e "  ${CYAN}1)${RESET} Full server"
        echo -e "  ${CYAN}2)${RESET} World data only"
        echo -e "  ${CYAN}3)${RESET} Server configuration"
        echo -e "  ${CYAN}0)${RESET} Back"
        echo ""

        read -rp "Enter choice [0-3]: " type

        case "$type" in
            0)
                info "Back to server selection..."
                sleep 1
                break
                ;;
            1)
                LABEL="Full server"
                FILE="${SERVER_NAME}_full_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE" -C "$SERVER_DIR" .)
                ;;
            2)
                LABEL="World data only"

                [ -d "$SERVER_DIR/worlds" ] ||
                    { warn "No worlds directory found in $SERVER_NAME."; sleep 1; continue; }

                FILE="${SERVER_NAME}_worlds_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE" -C "$SERVER_DIR" worlds)
                ;;
            3)
                LABEL="Server configuration"
                FILES=()

                for file in server.properties permissions.json allowlist.json valid_known_packs.json; do
                    [ -f "$SERVER_DIR/$file" ] && FILES+=("$file")
                done

                [ "${#FILES[@]}" -gt 0 ] ||
                    { warn "No server configuration files found."; sleep 1; continue; }

                FILE="${SERVER_NAME}_config_$(date +%Y%m%d_%H%M%S).tar.gz"
                COMMAND=(tar -czf "$BACKUP_DIR/$FILE" -C "$SERVER_DIR" "${FILES[@]}")
                ;;
            *)
                err "Invalid backup choice."
                sleep 1
                continue
                ;;
        esac

        BACKUP_FILE="$BACKUP_DIR/$FILE"

        echo ""
        ok "Server : $SERVER_NAME"
        ok "Version: $SERVER_VERSION"
        ok "Type   : $LABEL"
        echo ""

        read -rp "Continue with backup? [y/N]: " confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            warn "Backup cancelled."
            sleep 1
            continue
        fi

        echo ""
        info "Creating backup..."

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
        info "Returning to backup type..."
        sleep 2
    done
done