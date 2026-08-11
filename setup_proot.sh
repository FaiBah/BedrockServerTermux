#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; exit 1; }

# Check Termux
[ "$PREFIX" = "/data/data/com.termux/files/usr" ] &&
[ -d "/data/data/com.termux" ] ||
    err "This script must be run inside Termux."

ok "Termux detected."

# Check / install / update proot-distro
if command -v proot-distro >/dev/null 2>&1; then
    ok "proot-distro already installed."

    info "Checking for proot-distro updates..."

    pkg update -y >/dev/null 2>&1 ||
        warn "Failed to update Termux package lists."

    pkg upgrade proot-distro -y ||
        warn "Failed to update proot-distro."
else
    info "Installing proot-distro..."

    pkg install proot-distro -y ||
        err "Failed to install proot-distro."

    ok "proot-distro installed."
fi

# Check / install Debian
if proot-distro login debian -- true >/dev/null 2>&1; then
    ok "Debian is already installed."
else
    info "Installing Debian..."

    proot-distro install debian ||
        err "Debian installation failed."

    ok "Debian installed."
fi

# Check / create pdd
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

echo ""
echo -e "${GREEN}${BOLD}✓ BedrockServerTermux environment ready!${RESET}"
echo ""