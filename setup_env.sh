#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info() { echo -e "${CYAN}[*]${RESET} $1"; }
ok()   { echo -e "${GREEN}[✓]${RESET} $1"; }
err()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }

REPO="https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main"
SERVER_DIR="$HOME/Bedrock Server"
PACKAGES="git box64 sudo jq unzip tar curl wget gpg rsync"

# Check Debian
if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run inside Debian as root."
fi

ok "Debian environment detected."

# Update package lists
info "Updating package lists..."
apt update -y ||
    err "Failed to update package lists."

# Check dependencies
info "Checking dependencies..."

MISSING=""

for pkg in $PACKAGES; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg is installed."
    else
        MISSING="$MISSING $pkg"
    fi
done

# Install missing dependencies
if [ -n "$MISSING" ]; then
    info "Installing missing packages:$MISSING"

    apt install -y $MISSING ||
        err "Failed to install dependencies."
else
    ok "All dependencies are installed."
fi

# Download setup_server.sh
mkdir -p "$SERVER_DIR"

info "Downloading setup_server.sh..."

wget -q "$REPO/setup_server.sh" \
    -O "$SERVER_DIR/setup_server.sh" ||
    err "Failed to download setup_server.sh."

chmod +x "$SERVER_DIR/setup_server.sh"

ok "setup_server.sh downloaded."

echo ""
echo -e "${GREEN}${BOLD}✓ Environment setup complete!${RESET}"
echo ""
echo -e "  ${BOLD}Next:${RESET}"
echo -e "  ${CYAN}cd ~/Bedrock\\ Server${RESET}"
echo -e "  ${CYAN}./setup_server.sh${RESET}"
echo ""