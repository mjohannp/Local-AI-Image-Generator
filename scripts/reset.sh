#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/app"

echo ""
echo "  ============================================================"
echo "   Resetting Local-AI-Image-Generator..."
echo "  ============================================================"
echo ""

TOOLS_DIR="$APP_DIR/tools"
if [ -d "$TOOLS_DIR" ]; then
    echo "   >> Removing portable tools/ node folder..."
    rm -rf "$TOOLS_DIR"
fi

BACKEND_DIR="$APP_DIR/backend"
if [ -d "$BACKEND_DIR" ]; then
    echo "   >> Removing backend binaries..."
    rm -rf "$BACKEND_DIR"
fi

DIST_DIR="$APP_DIR/dist"
if [ -d "$DIST_DIR" ]; then
    echo "   >> Removing dist/ build folder..."
    rm -rf "$DIST_DIR"
fi

MODELS_DIR="$APP_DIR/models"
if [ -d "$MODELS_DIR" ]; then
    echo "   >> Preserving downloaded models in app/models."
fi

NODE_MODULES_DIR="$APP_DIR/frontend/node_modules"
if [ -d "$NODE_MODULES_DIR" ]; then
    echo "   >> Removing frontend node_modules..."
    rm -rf "$NODE_MODULES_DIR"
fi

LOCK_FILE="$APP_DIR/frontend/package-lock.json"
if [ -f "$LOCK_FILE" ]; then
    echo "   >> Removing frontend package-lock.json..."
    rm -f "$LOCK_FILE"
fi

echo ""
echo "  ============================================================"
echo "   Reset complete. Models and generated outputs were preserved."
echo "  ============================================================"
echo ""
read -r -p "  Press Enter to close..."
