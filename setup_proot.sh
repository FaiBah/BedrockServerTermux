#!/bin/bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; exit 1; }

# Check Termux
if [ "${PREFIX:-}" != "/data/data/com.termux/files/usr" ] ||
   [ ! -d "/data/data/com.termux" ]; then
    err "This script must be run inside Termux."
fi

ok "Termux detected."

# Update Termux
info "Updating Termux packages..."
pkg update -y || err "Failed to update Termux packages."

# Install / update proot-distro
info "Installing / updating proot-distro..."
pkg install proot-distro -y ||
    err "Failed to install proot-distro."
ok "proot-distro ready."

# Install Debian if needed
if proot-distro list-installed 2>/dev/null |
    grep -qE '^\s*debian\s*$'; then
    ok "Debian is already installed."
else
    info "Installing Debian..."
    proot-distro install debian ||
        err "Debian installation failed."
    ok "Debian installed."
fi

# Create / update pdd
PDD="$PREFIX/bin/pdd"

cat > "$PDD" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login debian "$@"
EOF

chmod +x "$PDD"
ok "'pdd' is ready."

echo ""
echo -e "${GREEN}${BOLD}✓ BedrockServerTermux environment ready!${RESET}"
echo ""
echo "Run 'pdd' to enter Debian."
echo ""
