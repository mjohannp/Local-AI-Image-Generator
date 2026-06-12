#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP="$SCRIPT_DIR/app"
NODE="$APP/tools/node-mac/bin/node"
DIST="$APP/dist/index.html"
SERVE="$SCRIPT_DIR/scripts/serve.cjs"
FRONTEND_PORT="${FRONTEND_PORT:-1420}"
SETUP="$SCRIPT_DIR/scripts/setup.sh"

# ── Setup check ───────────────────────────────────────────────────────────────

SETUP_NEEDED=false
SETUP_REASON=""

if [ ! -x "$NODE" ]; then
    SETUP_NEEDED=true
    SETUP_REASON="Portable Node.js is missing."
elif [ ! -f "$DIST" ]; then
    SETUP_NEEDED=true
    SETUP_REASON="Frontend build is missing."
elif [ ! -x "$APP/backend/mac/sd" ]; then
    SETUP_NEEDED=true
    SETUP_REASON="No backend binary is installed."
fi

if [ "$SETUP_NEEDED" = true ]; then
    echo ""
    echo "  ============================================================"
    echo "   LOCAL AI IMAGE GENERATOR  |  Setup Required"
    echo "  ============================================================"
    echo ""
    echo "  Reason: $SETUP_REASON"
    echo "  Models are not downloaded during setup. Download them in the app."
    echo ""
    echo "  Press Enter to continue, or Ctrl+C to cancel."
    read -r

    bash "$SETUP"
    if [ $? -ne 0 ]; then
        echo ""
        echo "  [ERROR] Setup failed."
        exit 1
    fi
fi

# ── Launch ────────────────────────────────────────────────────────────────────

echo ""
echo "  ============================================================"
echo "   LOCAL AI IMAGE GENERATOR  |  Launching..."
echo "  ============================================================"
echo ""

echo "Clearing frontend port $FRONTEND_PORT..."
lsof -ti:"$FRONTEND_PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true

echo "Starting Local AI Image Generator..."
"$NODE" "$SERVE" &
SERVER_PID=$!

sleep 2

echo "Opening browser at http://localhost:$FRONTEND_PORT"
open "http://localhost:$FRONTEND_PORT"

echo ""
echo "  ============================================================"
echo "   Running!"
echo "   Web UI:     http://localhost:$FRONTEND_PORT"
echo "   GPU API:    Auto-selected by the app (starts at 8080)"
echo ""
echo "   Press Ctrl+C to stop all services."
echo "  ============================================================"
echo ""

cleanup() {
    echo "Shutting down..."
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    echo "Done. Goodbye!"
}
trap cleanup EXIT INT TERM

wait "$SERVER_PID"
