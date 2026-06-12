# macOS Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Local AI Image Generator from Windows-only to macOS Apple Silicon, using stable-diffusion.cpp's Metal backend.

**Architecture:** Create macOS equivalents of all Windows scripts (start.sh, setup.sh, reset.sh) and extend serve.cjs with macOS-specific GPU detection, Metal backend support, and unified memory monitoring. The frontend code requires no changes.

**Tech Stack:** Bash, Node.js (portable), stable-diffusion.cpp macOS arm64 binary with Metal, curl/unzip for downloads.

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `.gitignore` | Already ignores `app/tools/` and `app/backend/` — no changes needed |
| Create | `scripts/setup.sh` | Downloads portable Node.js + sd.cpp Metal binary, builds frontend |
| Create | `scripts/reset.sh` | Cleans runtime files, preserves models/outputs |
| Create | `start.sh` | macOS launcher — setup check, server start, browser open |
| Modify | `scripts/serve.cjs` | macOS GPU info, Metal backend option, unified memory stats |
| Modify | `README.md` | Add macOS quick start and compatibility info |

---

### Task 1: Create `scripts/reset.sh`

**Files:**
- Create: `scripts/reset.sh`

- [ ] **Step 1: Write the reset script**

```bash
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
```

- [ ] **Step 2: Make executable and verify**

Run: `chmod +x scripts/reset.sh && head -1 scripts/reset.sh`
Expected: `#!/usr/bin/env bash`

- [ ] **Step 3: Commit**

```bash
git add scripts/reset.sh
git commit -m "feat: add macOS reset script"
```

---

### Task 2: Create `scripts/setup.sh`

**Files:**
- Create: `scripts/setup.sh`

- [ ] **Step 1: Write the setup script**

```bash
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
```

- [ ] **Step 2: Make executable and verify syntax**

Run: `chmod +x scripts/setup.sh && bash -n scripts/setup.sh`
Expected: No output (no syntax errors)

- [ ] **Step 3: Commit**

```bash
git add scripts/setup.sh
git commit -m "feat: add macOS setup script with portable Node.js and Metal backend"
```

---

### Task 3: Create `start.sh`

**Files:**
- Create: `start.sh`

- [ ] **Step 1: Write the launcher script**

```bash
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
```

- [ ] **Step 2: Make executable and verify syntax**

Run: `chmod +x start.sh && bash -n start.sh`
Expected: No output (no syntax errors)

- [ ] **Step 3: Commit**

```bash
git add start.sh
git commit -m "feat: add macOS launcher script"
```

---

### Task 4: Extend `serve.cjs` for macOS

**Files:**
- Modify: `scripts/serve.cjs`

This task requires 5 edits to the same file, all enabling macOS-specific behavior.

- [ ] **Step 1: Add macOS GPU detection to `getGpuInfo()`**

In `scripts/serve.cjs`, after line 133 (`if (cachedGpuInfo) return cachedGpuInfo;`) and before line 134 (`if (osPlatform === "win32") {`), insert a macOS branch:

```js
  if (osPlatform === "darwin") {
    try {
      const output = execSync(
        "system_profiler SPDisplaysDataType 2>/dev/null | grep 'Chipset Model' | head -1 | sed 's/.*: //' | xargs",
        { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
      ).trim();
      if (output) {
        cachedGpuInfo = { name: output };
        return cachedGpuInfo;
      }
    } catch (_) {}
  }
```

- [ ] **Step 2: Add Metal backend option to `getBackendOptions()`**

In `scripts/serve.cjs`, replace the `getBackendOptions` function body (lines 517-558) with:

```js
function getBackendOptions() {
  if (cachedBackendOptions) return cachedBackendOptions;

  const cudaAvailable = osPlatform === "win32" && hasNvidiaGpu() && backendAccepts(BACKEND_PATHS.cuda, "cuda");
  const cudaInstalled = osPlatform === "win32" && fs.existsSync(BACKEND_PATHS.cuda);
  const vulkanInstalled = (osPlatform === "win32" && fs.existsSync(BACKEND_PATHS.vulkan)) ||
                          (osPlatform === "linux" && fs.existsSync(BACKEND_PATHS.linux));
  const vulkanAvailable = vulkanInstalled && backendAccepts(
    osPlatform === "win32" ? BACKEND_PATHS.vulkan : BACKEND_PATHS.linux,
    "vulkan"
  );
  const metalInstalled = osPlatform === "darwin" && fs.existsSync(BACKEND_PATHS.mac);
  const metalAvailable = metalInstalled && backendAccepts(BACKEND_PATHS.mac, "metal");
  const options = [{ id: "cpu", label: "CPU", available: true }];
  if (vulkanAvailable) options.push({ id: "vulkan", label: "Vulkan GPU", available: true });
  if (cudaAvailable) options.push({ id: "cuda", label: "CUDA GPU", available: true });
  if (metalAvailable) options.push({ id: "metal", label: "Metal GPU", available: true });
  const unavailable = [];
  if (vulkanInstalled && !vulkanAvailable) {
    unavailable.push({ id: "vulkan", label: "Vulkan GPU", reason: "Installed, but this binary did not register a Vulkan backend on this machine." });
  }
  if (cudaInstalled && !cudaAvailable) {
    unavailable.push({ id: "cuda", label: "CUDA GPU", reason: "Installed, but CUDA backend validation failed." });
  }
  if (metalInstalled && !metalAvailable) {
    unavailable.push({ id: "metal", label: "Metal GPU", reason: "Installed, but Metal backend validation failed." });
  }
  let defaultBackend = "cpu";
  if (cudaAvailable) {
    const gpuName = String(getGpuInfo().name).toLowerCase();
    const isGtxCard = gpuName.includes("gtx");
    if (isGtxCard && vulkanAvailable) {
      defaultBackend = "vulkan";
    } else {
      defaultBackend = "cuda";
    }
  } else if (metalAvailable) {
    defaultBackend = "metal";
  } else if (vulkanAvailable) {
    defaultBackend = "vulkan";
  }

  cachedBackendOptions = {
    options,
    unavailable,
    cudaAvailable,
    vulkanAvailable,
    metalAvailable,
    defaultBackendType: defaultBackend,
  };
  return cachedBackendOptions;
}
```

- [ ] **Step 3: Add macOS branch to `selectBackendPath()`**

In `scripts/serve.cjs`, replace the `selectBackendPath` function (lines 579-588) with:

```js
function selectBackendPath(useGpu, backendType = "auto") {
  const resolvedType = resolveBackendType(useGpu, backendType);
  if (osPlatform === "win32" && resolvedType === "cuda" && fs.existsSync(BACKEND_PATHS.cuda)) {
    return BACKEND_PATHS.cuda;
  }
  if (osPlatform === "win32" && fs.existsSync(BACKEND_PATHS.vulkan)) {
    return BACKEND_PATHS.vulkan;
  }
  if (osPlatform === "darwin" && fs.existsSync(BACKEND_PATHS.mac)) {
    return BACKEND_PATHS.mac;
  }
  return BACKEND_PATH;
}
```

- [ ] **Step 4: Add Metal to `getBackendMode()` and backend args in `startBackend()`**

Replace `getBackendMode` function (lines 597-603) with:

```js
function getBackendMode(backendPath, useGpu, backendType = "auto") {
  if (useGpu === false || backendType === "cpu") return "CPU";
  if (backendType === "metal") return "Metal GPU";
  const name = path.basename(backendPath || "").toLowerCase();
  if (name.includes("cuda")) return "CUDA GPU";
  if (name.includes("vulkan")) return "Vulkan GPU";
  return "GPU";
}
```

Add a Metal args block in `startBackend()`. After the CUDA block (line 766, `);`) and before line 767 (`}`), insert:

```js
  } else if (requestedBackend === "metal") {
    args.push(
      "--backend", "metal",
      "--params-backend", "metal",
      "--rng", "cpu",
      "--sampler-rng", "cpu",
    );
```

- [ ] **Step 5: Add Metal detection in stderr parser**

In the `backendProc.stderr.on("data", ...)` handler, after the Vulkan detection block (line 874-875) and before the `[ERROR]` check (line 876), insert:

```js
    if (cleanOutput.includes("ggml_metal") || cleanOutput.includes("Metal ")) {
      backendLoadState.backendMode = "Metal GPU";
      currentSettings.backendMode = "Metal GPU";
    }
```

- [ ] **Step 6: Add macOS memory polling**

After line 216 (`pollNvidiaVram(true);`), insert a macOS memory polling block:

```js

// macOS unified memory polling
if (osPlatform === "darwin") {
  setInterval(() => {
    if (backendProc !== null) return;
    const totalMem = os.totalmem();
    const freeMem = os.freemem();
    const usedMem = totalMem - freeMem;
    const gpuInfo = getGpuInfo();
    cachedVramInfo = {
      gpu_name: gpuInfo.name,
      vram_used_gb: roundGb(usedMem),
      vram_total_gb: roundGb(totalMem),
    };
  }, 5000);
  // Initial poll
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  cachedVramInfo = {
    gpu_name: getGpuInfo().name,
    vram_used_gb: roundGb(totalMem - freeMem),
    vram_total_gb: roundGb(totalMem),
  };
}
```

- [ ] **Step 7: Verify syntax**

Run: `node -c scripts/serve.cjs`
Expected: No output (no syntax errors)

- [ ] **Step 8: Commit**

```bash
git add scripts/serve.cjs
git commit -m "feat: add macOS Metal backend support to serve.cjs"
```

---

### Task 5: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add macOS section to the Quick Start**

After the existing Quick Start section, add a macOS Quick Start block. Replace the section starting at "## Quick Start" with:

```markdown
## Quick Start

### Windows
1. **Launch:** Double-click **`start.bat`** (downloads portable Node.js and pre-compiled GPU backend binaries on first run).
2. **Add Models:** Drop `.safetensors`, `.gguf`, or `.ckpt` weights into `app/models/` (or download them via the **Model Manager** tab in the UI).
3. **Generate:** Open `http://localhost:1420` in your browser, select your model, and write a prompt.

### macOS (Apple Silicon)
1. **Launch:** Open Terminal, navigate to the project folder, and run `./start.sh` (downloads portable Node.js and Metal backend binary on first run).
2. **Add Models:** Drop `.safetensors`, `.gguf`, or `.ckpt` weights into `app/models/` (or download them via the **Model Manager** tab in the UI).
3. **Generate:** The browser opens automatically at `http://localhost:1420` — select your model and write a prompt.
```

- [ ] **Step 2: Update GPU Compatibility Matrix**

Replace the GPU Compatibility Matrix table with:

```markdown
## GPU Compatibility Matrix

| GPU Vendor | Tech | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Nvidia** | CUDA | Native | Maps `sd-cuda.exe` with Nvidia SDK 12 optimizations. |
| **AMD Radeon** | Vulkan | Native | Maps `sd-vulkan.exe` with Vulkan API acceleration. |
| **Intel Arc** | Vulkan | Native | Maps `sd-vulkan.exe` for Intel hardware. |
| **Apple Silicon** | Metal | Native | Maps `sd` (macOS arm64) with Metal GPU acceleration. |
| **Integrated / None** | CPU | Fallback | Runs on logical CPU threads (slow). |
```

- [ ] **Step 3: Update overview text**

Change the overview line (line 25) from:

```
**Local AI Image Generator** is a zero-configuration, portable desktop environment for running Stable Diffusion (Safetensors/GGUF/CKPT) offline on Windows.
```

to:

```
**Local AI Image Generator** is a zero-configuration, portable desktop environment for running Stable Diffusion (Safetensors/GGUF/CKPT) offline on **Windows** and **macOS (Apple Silicon)**.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add macOS quick start and Metal GPU to compatibility matrix"
```

---

### Task 6: End-to-end verification

- [ ] **Step 1: Run setup**

Run: `./scripts/setup.sh`
Expected: Downloads Node.js, Metal backend, builds frontend. All 4 steps show "OK".

- [ ] **Step 2: Verify file structure**

Run: `ls -la app/tools/node-mac/bin/node app/backend/mac/sd app/dist/index.html`
Expected: All three files exist.

- [ ] **Step 3: Verify Metal backend probe**

Run: `./app/backend/mac/sd --help 2>&1 | head -5`
Expected: Shows usage/help output confirming the binary runs.

- [ ] **Step 4: Launch the app**

Run: `./start.sh`
Expected: Server starts on port 1420, browser opens, UI loads. Backend shows "Metal GPU" option.

- [ ] **Step 5: Final commit (if any fixes were needed)**

```bash
git add -A
git commit -m "fix: address issues found during end-to-end verification"
```
