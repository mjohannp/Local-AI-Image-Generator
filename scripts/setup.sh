#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
FRONTEND_DIR="$APP_DIR/frontend"
TOOLS_DIR="$APP_DIR/tools"
NODE_DIR="$TOOLS_DIR/node-mac"
NODE_BIN="$NODE_DIR/bin/node"
NPM_BIN="$NODE_DIR/bin/npm"
DIST_DIR="$APP_DIR/dist"
BACKEND_DIR="$APP_DIR/backend/mac"
BACKEND_BIN="$BACKEND_DIR/sd"

# Download URLs
NODE_VERSION="22.12.0"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-arm64.tar.gz"
SD_RELEASE="master-685-19bdfe2"
SD_COMMIT="19bdfe2"
SD_URL="https://github.com/leejet/stable-diffusion.cpp/releases/download/${SD_RELEASE}/sd-master-${SD_COMMIT}-bin-Darwin-macOS-15.7.7-arm64.zip"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TOTAL_STEPS=4

print_step() {
    echo ""
    echo "  [$1/$TOTAL_STEPS] $3"
    echo "  --------------------------------------------------------"
}

print_ok()   { echo -e "   ${GREEN}OK${NC}  $1"; }
print_info() { echo -e "   ${CYAN}>>${NC}  $1"; }
print_warn() { echo -e "   ${YELLOW}!!${NC}  $1"; }
print_fail() { echo -e "   ${RED}XX${NC}  $1"; }

download_with_progress() {
    local url="$1"
    local dest="$2"
    local label="$3"
    print_info "Downloading: $label"
    if curl -L --progress-bar -o "$dest" "$url" 2>&1; then
        print_ok "$label downloaded"
    else
        print_fail "Download failed: $label"
        return 1
    fi
}

clear
echo ""
echo "  ============================================================"
echo "   LOCAL AI IMAGE GENERATOR  -  macOS Setup"
echo "   100% Self-Contained  |  No System Install Required"
echo "  ============================================================"
echo ""

# ── Step 1: Portable Node.js ─────────────────────────────────────────────────

print_step 1 "$TOTAL_STEPS" "Setting up portable Node.js (app/tools/node-mac/)"

if [ -x "$NODE_BIN" ] && [ -x "$NPM_BIN" ]; then
    NODE_VER=$("$NODE_BIN" --version)
    print_ok "Portable Node.js already ready: $NODE_VER"
else
    mkdir -p "$TOOLS_DIR"
    NODE_ARCHIVE="$TOOLS_DIR/node.tar.gz"

    download_with_progress "$NODE_URL" "$NODE_ARCHIVE" "Node.js v${NODE_VERSION} (macOS arm64)"

    print_info "Extracting Node.js..."
    tar -xzf "$NODE_ARCHIVE" -C "$TOOLS_DIR"
    rm -f "$NODE_ARCHIVE"

    EXTRACTED=$(find "$TOOLS_DIR" -maxdepth 1 -type d -name "node-v*" | head -1)
    if [ -n "$EXTRACTED" ]; then
        [ -d "$NODE_DIR" ] && rm -rf "$NODE_DIR"
        mv "$EXTRACTED" "$NODE_DIR"
    fi

    if [ ! -x "$NODE_BIN" ] || [ ! -x "$NPM_BIN" ]; then
        print_fail "Portable Node.js install is incomplete."
        exit 1
    fi

    NODE_VER=$("$NODE_BIN" --version)
    print_ok "Portable Node.js ready: $NODE_VER"
fi

# ── Step 2: stable-diffusion.cpp Metal Backend ──────────────────────────────

print_step 2 "$TOTAL_STEPS" "Setting up stable-diffusion.cpp Metal backend (app/backend/mac/)"

if [ -x "$BACKEND_BIN" ]; then
    print_ok "Metal backend binary already ready."
else
    mkdir -p "$TOOLS_DIR" "$BACKEND_DIR"
    SD_ARCHIVE="$TOOLS_DIR/sd-mac.zip"

    download_with_progress "$SD_URL" "$SD_ARCHIVE" "stable-diffusion.cpp Metal Backend (macOS arm64)"

    TEMP_EXT="$TOOLS_DIR/sd-mac-temp"
    mkdir -p "$TEMP_EXT"

    print_info "Extracting Metal Backend..."
    unzip -o -q "$SD_ARCHIVE" -d "$TEMP_EXT"
    rm -f "$SD_ARCHIVE"

    FOUND_EXE=""
    for candidate in "$TEMP_EXT/bin/sd-server" "$TEMP_EXT/sd-server" "$TEMP_EXT/bin/sd" "$TEMP_EXT/sd"; do
        if [ -f "$candidate" ]; then
            FOUND_EXE="$candidate"
            break
        fi
    done

    if [ -n "$FOUND_EXE" ]; then
        cp "$FOUND_EXE" "$BACKEND_BIN"
        chmod +x "$BACKEND_BIN"
    fi

    # Copy shared libraries (.dylib) alongside the binary
    find "$TEMP_EXT" -name "*.dylib" -exec cp {} "$BACKEND_DIR/" \;

    rm -rf "$TEMP_EXT"

    if [ ! -x "$BACKEND_BIN" ]; then
        print_fail "Failed to set up Metal backend binary."
        exit 1
    fi

    print_ok "Metal backend binary installed!"
fi

# ── Step 3: npm install ──────────────────────────────────────────────────────

print_step 3 "$TOTAL_STEPS" "Installing frontend dependencies (app/frontend/)"

if [ ! -x "$NPM_BIN" ]; then
    print_fail "npm not found at $NPM_BIN"
    exit 1
fi

cd "$FRONTEND_DIR"
PATH="$NODE_DIR/bin:$PATH" "$NPM_BIN" install --prefer-offline 2>&1 || {
    print_fail "npm install failed."
    exit 1
}
print_ok "Dependencies installed!"

# ── Step 4: Build frontend ───────────────────────────────────────────────────

print_step 4 "$TOTAL_STEPS" "Building frontend -> app/dist/"

PATH="$NODE_DIR/bin:$PATH" "$NPM_BIN" run build 2>&1 || {
    print_fail "Frontend build failed."
    exit 1
}
print_ok "Frontend built!"

echo ""
echo -e "  ${GREEN}============================================================${NC}"
echo -e "   ${GREEN}Setup complete! Run ./start.sh to launch.${NC}"
echo -e "  ${GREEN}============================================================${NC}"
echo ""
