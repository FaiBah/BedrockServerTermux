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

REPO="https://github.com/FaiBah/BedrockServerTermux"

SERVER_ROOT="$HOME/Bedrock Server"
SERVER_DATA="$SERVER_ROOT/Data"
BACKUP_ROOT="$SERVER_ROOT/Backups"

PACKAGES="git box64 sudo jq unzip tar curl wget gpg rsync"

# ── Check Debian ───────────────────────────────────────────
if [ ! -f "/etc/debian_version" ] ||
   ! command -v apt >/dev/null 2>&1 ||
   ! command -v dpkg >/dev/null 2>&1; then
    err "This script must be run inside Debian."
fi

if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run as root inside Debian."
fi

ok "Debian environment detected."

# ── Update package lists ───────────────────────────────────
info "Updating package lists..."

apt update -y \
    || err "Failed to update package lists."

ok "Package lists updated."

# ── Check dependencies ─────────────────────────────────────
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

    apt install -y $MISSING \
        || err "Failed to install dependencies."

    ok "Missing dependencies installed."
else
    ok "All required packages are installed."
fi

# ── Update dependencies ────────────────────────────────────
info "Updating installed dependencies..."

apt install --only-upgrade -y $PACKAGES \
    || err "Failed to update dependencies."

ok "Dependencies updated."

# ── Create server directories ───────────────────────────────
if [ -d "$SERVER_ROOT" ]; then
    ok "Bedrock Server directory already exists."
else
    info "Creating Bedrock Server directory..."

    mkdir -p "$SERVER_ROOT"

    ok "Bedrock Server directory created."
fi

if [ -d "$SERVER_DATA" ]; then
    ok "Data directory already exists."
else
    info "Creating Data directory..."

    mkdir -p "$SERVER_DATA"

    ok "Data directory created."
fi

if [ -d "$BACKUP_ROOT" ]; then
    ok "Backups directory already exists."
else
    info "Creating Backups directory..."

    mkdir -p "$BACKUP_ROOT"

    ok "Backups directory created."
fi

# ── Download manager files ─────────────────────────────────
info "Downloading manager files..."

TMP_DIR="$(mktemp -d)"
ZIP_FILE="$TMP_DIR/repo.zip"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

info "Downloading repository..."

curl -fsSL \
    "$REPO/archive/refs/heads/main.zip" \
    -o "$ZIP_FILE" \
    || err "Failed to download repository."

ok "Repository downloaded."

info "Extracting manager files..."

unzip -q "$ZIP_FILE" -d "$TMP_DIR" \
    || err "Failed to extract repository."

REPO_DIR="$TMP_DIR/BedrockServerTermux-main"

if [ ! -f "$REPO_DIR/manage.sh" ]; then
    err "manage.sh not found in repository."
fi

if [ ! -d "$REPO_DIR/menu" ]; then
    err "menu directory not found in repository."
fi

# ── Install manage.sh ──────────────────────────────────────
info "Installing manage.sh..."

cp -f \
    "$REPO_DIR/manage.sh" \
    "$SERVER_ROOT/manage.sh"

chmod +x "$SERVER_ROOT/manage.sh"

ok "manage.sh installed."

# ── Install entire menu directory ──────────────────────────
info "Installing menu..."

rm -rf "$SERVER_ROOT/menu"

cp -r \
    "$REPO_DIR/menu" \
    "$SERVER_ROOT/menu"

chmod +x "$SERVER_ROOT"/menu/*.sh

ok "Menu installed."

# ── Create bds command ─────────────────────────────────────
BDS_BIN="/usr/local/bin/bds"

info "Creating 'bds' command..."

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
echo -e "  ${BOLD}Server data:${RESET} $SERVER_DATA"
echo -e "  ${BOLD}Backups:${RESET}     $BACKUP_ROOT"
echo ""
echo -e "  ${BOLD}Run:${RESET} bds"
echo ""