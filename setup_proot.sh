#!/bin/bash

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

# Check Termux
if [ "$PREFIX" != "/data/data/com.termux/files/usr" ] ||
   [ ! -d "/data/data/com.termux" ]; then
    err "This script must be run inside Termux."
fi

ok "Termux detected."

# Check proot-distro
if ! command -v proot-distro >/dev/null 2>&1; then
    info "Installing proot-distro..."
    pkg install proot-distro -y ||
        err "Failed to install proot-distro."
else
    ok "proot-distro already installed."
fi

# Check Debian
if proot-distro login debian -- echo >/dev/null 2>&1; then
    ok "Debian is already installed."
else
    info "Installing Debian..."
    proot-distro install debian ||
        err "Debian installation failed."
fi

# Check pdd
PDD="$PREFIX/bin/pdd"

if [ -x "$PDD" ]; then
    ok "'pdd' already exists."
else
    info "Creating 'pdd' command..."

    cat > "$PDD" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login debian
EOF

    chmod +x "$PDD"
    ok "'pdd' created."
fi

# Create Bedrock Server directory
proot-distro login debian -- mkdir -p "/root/Bedrock Server" ||
    err "Failed to create Bedrock Server directory."

echo ""
echo -e "${GREEN}${BOLD}✓ BedrockTermux setup complete!${RESET}"
echo ""
echo -e "  ${BOLD}Enter Debian:${RESET} ${CYAN}pdd${RESET}"
echo ""
echo -e "  ${BOLD}Next:${RESET}"
echo -e "  ${CYAN}pdd${RESET}"
echo -e "  ${CYAN}cd ~/Bedrock\\ Server${RESET}"
echo -e "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/FaiBah/BedrockServerTermux/main/setup_env.sh | bash${RESET}"
echo ""