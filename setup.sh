#!/bin/bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info(){ echo -e "${CYAN}[*]${RESET} $1"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $1"; }
err(){ echo -e "${RED}[✗]${RESET} $1"; exit 1; }

REPO="https://github.com/FaiBah/BedrockServerTermux"
SERVER_ROOT="$HOME/BedrockServerTermux"
SERVER_DATA="$SERVER_ROOT/Servers"
BACKUP_ROOT="$SERVER_ROOT/Backups"
PACKAGES="git box64 jq unzip tar curl wget gpg rsync"

# Check Debian
if [ ! -f "/etc/debian_version" ] ||
   ! command -v apt >/dev/null 2>&1 ||
   ! command -v dpkg >/dev/null 2>&1; then
    err "This script must be run inside Debian."
fi

[ "$(id -u)" -eq 0 ] ||
    err "This script must be run as root inside Debian."

ok "Debian environment detected."

# Update package lists
info "Updating package lists..."
apt update -y || err "Failed to update package lists."
ok "Package lists updated."

# Install missing dependencies
info "Checking dependencies..."

MISSING=""

for pkg in $PACKAGES; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg is installed."
    else
        MISSING="$MISSING $pkg"
    fi
done

if [ -n "$MISSING" ]; then
    info "Installing missing packages:$MISSING"
    apt install -y $MISSING ||
        err "Failed to install dependencies."
    ok "Dependencies installed."
else
    ok "All required packages are installed."
fi

# Create directories
for dir in "$SERVER_ROOT" "$SERVER_DATA" "$BACKUP_ROOT"; do
    if [ -d "$dir" ]; then
        ok "$(basename "$dir") directory already exists."
    else
        mkdir -p "$dir"
        ok "$(basename "$dir") directory created."
    fi
done

# Download repository
info "Downloading manager files..."

TMP_DIR="$(mktemp -d)"
ZIP_FILE="$TMP_DIR/repo.zip"

cleanup(){ rm -rf "$TMP_DIR"; }
trap cleanup EXIT

curl -fsSL \
    "$REPO/archive/refs/heads/main.zip" \
    -o "$ZIP_FILE" ||
    err "Failed to download repository."

ok "Repository downloaded."

# Extract repository
unzip -q "$ZIP_FILE" -d "$TMP_DIR" ||
    err "Failed to extract repository."

REPO_DIR="$TMP_DIR/BedrockServerTermux-main"

[ -f "$REPO_DIR/manage.sh" ] ||
    err "manage.sh not found in repository."

[ -d "$REPO_DIR/menu" ] ||
    err "menu directory not found in repository."

# Install manager
info "Installing manage.sh..."

cp -f "$REPO_DIR/manage.sh" "$SERVER_ROOT/manage.sh"
chmod +x "$SERVER_ROOT/manage.sh"

ok "manage.sh installed."

# Install menu
info "Installing menu..."

rm -rf "$SERVER_ROOT/menu"
cp -r "$REPO_DIR/menu" "$SERVER_ROOT/menu"
chmod +x "$SERVER_ROOT"/menu/*.sh

ok "Menu installed."

# Create bds command
BDS_BIN="/usr/local/bin/bds"

cat > "$BDS_BIN" <<EOF
#!/bin/bash
exec "$SERVER_ROOT/manage.sh"
EOF

chmod +x "$BDS_BIN"

ok "'bds' command created."

echo ""
echo -e "${GREEN}${BOLD}✓ BedrockServerTermux setup complete!${RESET}"
echo ""
echo -e "  ${BOLD}Server root:${RESET} $SERVER_ROOT"
echo -e "  ${BOLD}Servers:${RESET}     $SERVER_DATA"
echo -e "  ${BOLD}Backups:${RESET}     $BACKUP_ROOT"
echo ""
echo -e "  ${BOLD}Run:${RESET} bds"
echo ""