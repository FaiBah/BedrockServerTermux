#!/bin/bash
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

REPO="https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main"
SERVER_ROOT="$HOME/Bedrock Server"
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
    ok "All required packages are installed."
fi

# Update installed dependencies
info "Updating installed dependencies..."

apt install --only-upgrade -y $PACKAGES ||
    err "Failed to update dependencies."

# Create Bedrock Server directory
mkdir -p "$SERVER_ROOT"
cd "$SERVER_ROOT"

# Download install/update script
info "Downloading install_update.sh..."

wget -q "$REPO/install_update.sh" \
    -O install_update.sh ||
    err "Failed to download install_update.sh."

chmod +x install_update.sh

ok "install_update.sh downloaded."

echo ""
echo -e "${GREEN}${BOLD}✓ Environment setup complete!${RESET}"
echo ""
echo -e "  ${BOLD}Location:${RESET} $SERVER_ROOT"
echo -e "  ${BOLD}Next:${RESET} ./install_update.sh"
echo ""