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

# ── Debian branch ──────────────────────────────────────────
run_in_debian() {
    ok "Debian environment detected."

    info "Updating package lists..."
    apt update -y || err "Failed to update package lists."
    ok "Package lists updated."

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
        apt install -y $MISSING || err "Failed to install dependencies."
        ok "Missing dependencies installed."
    else
        ok "All required packages are installed."
    fi

    info "Updating installed dependencies..."
    apt install --only-upgrade -y $PACKAGES || err "Failed to update dependencies."
    ok "Dependencies updated."

    if [ -d "$SERVER_ROOT" ]; then
        ok "Bedrock Server directory already exists."
    else
        info "Creating Bedrock Server directory..."
        mkdir -p "$SERVER_ROOT"
        ok "Bedrock Server directory created."
    fi

    cd "$SERVER_ROOT"

    # Fetch manage.sh + menu/ from repo
    info "Downloading manager scripts..."

    TMP_DIR="$(mktemp -d)"

    git clone --depth 1 --filter=blob:none --sparse \
        https://github.com/FaiBah/BedrockServerTermux.git "$TMP_DIR" \
        >/dev/null 2>&1 || err "Failed to clone repo."

    (cd "$TMP_DIR" && git sparse-checkout set manage.sh menu >/dev/null 2>&1) \
        || err "Failed to fetch manager scripts."

    cp -f "$TMP_DIR/manage.sh" "$SERVER_ROOT/manage.sh"
    rm -rf "$SERVER_ROOT/menu"
    cp -r "$TMP_DIR/menu" "$SERVER_ROOT/menu"

    rm -rf "$TMP_DIR"

    chmod +x "$SERVER_ROOT/manage.sh" "$SERVER_ROOT"/menu/*.sh

    ok "manage.sh and menu/ downloaded."

    # Create bds command
    BDS_BIN="/usr/local/bin/bds"

    info "Creating 'bds' command..."
    cat > "$BDS_BIN" <<EOF
#!/bin/bash
exec "$SERVER_ROOT/manage.sh"
EOF
    chmod +x "$BDS_BIN"
    ok "'bds' command created."

    echo ""
    echo -e "${GREEN}${BOLD}✓ Environment setup complete!${RESET}"
    echo ""
    echo -e "  ${BOLD}Location:${RESET} $SERVER_ROOT"
    echo -e "  ${BOLD}Next:${RESET} bds"
    echo ""
}

# ── Termux branch ──────────────────────────────────────────
run_in_termux() {
    ok "Termux detected."

    if command -v proot-distro >/dev/null 2>&1; then
        ok "proot-distro already installed."
    else
        info "Installing proot-distro..."
        pkg install proot-distro -y || err "Failed to install proot-distro."
    fi

    if proot-distro login debian -- true >/dev/null 2>&1; then
        ok "Debian is already installed."
    else
        info "Installing Debian..."
        proot-distro install debian || err "Debian installation failed."
    fi

    # Create 'pdd' shortcut
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
    ok "Continuing setup inside Debian..."
    echo ""

    # Re-run this same script inside the Debian proot, as root
    proot-distro login debian -- bash -c \
        "curl -fsSL '$REPO/setup.sh' | bash"

    echo ""
    echo -e "${GREEN}${BOLD}✓ BedrockServerTermux ready!${RESET}"
    echo ""
    echo -e "  ${BOLD}Next:${RESET} pdd   (then run: bds)"
    echo ""
}

# ── Entry point ─────────────────────────────────────────────
if [ -d "/data/data/com.termux" ] && [ "${PREFIX:-}" = "/data/data/com.termux/files/usr" ]; then
    run_in_termux
elif [ "$(id -u)" -eq 0 ]; then
    run_in_debian
else
    err "This script must be run inside Termux or as root inside Debian."
fi