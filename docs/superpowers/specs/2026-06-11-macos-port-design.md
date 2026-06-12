# macOS Port Design

Port the Local AI Image Generator (originally Windows-only) to run on Apple Silicon Macs, using stable-diffusion.cpp's native macOS arm64 binary with Metal GPU support.

## Target Platform

- macOS on Apple Silicon (M1/M2/M3/M4)
- arm64 architecture only (matching the upstream binary availability)
- Metal GPU acceleration via stable-diffusion.cpp

## New Files

### `start.sh`
macOS launcher, equivalent to `start.bat`. Responsibilities:
- Detect if first-time setup is needed (missing portable Node.js, frontend build, or backend binary)
- Run `scripts/setup.sh` when setup is required
- Kill any existing process on the frontend port before launching
- Start `serve.cjs` using the portable Node.js at `app/tools/node-mac/bin/node`
- Open the default browser at `http://localhost:$FRONTEND_PORT`
- Trap SIGINT/SIGTERM for graceful shutdown (kill child server process)
- Make executable (`chmod +x`)

### `scripts/setup.sh`
macOS setup script, equivalent to `scripts/setup.ps1`. Four steps:

1. **Portable Node.js** — Download `node-v22.12.0-darwin-arm64.tar.gz` from nodejs.org, extract to `app/tools/node-mac/`. Skip if already present.

2. **stable-diffusion.cpp backend** — Download the macOS arm64 binary from GitHub releases (`sd-master-*-bin-Darwin-macOS-*-arm64.zip`), extract to `app/backend/mac/`, rename the server binary to `sd`. Skip if already present.

3. **Frontend npm install** — Run `npm install --prefer-offline` in `app/frontend/` using the portable npm.

4. **Frontend build** — Run `npm run build` in `app/frontend/` to produce `app/dist/`.

### `scripts/reset.sh`
macOS reset script, equivalent to `scripts/reset.ps1`. Deletes:
- `app/tools/` (portable Node.js)
- `app/backend/` (GPU binaries)
- `app/dist/` (built frontend)
- `app/frontend/node_modules/`
- `app/frontend/package-lock.json`

Preserves `app/models/` and `app/outputs/`.

## Modified Files

### `scripts/serve.cjs`
Changes needed for macOS support (the file already has partial macOS paths):

- **GPU info detection** — On `darwin`, use `system_profiler SPDisplaysDataType` to read GPU name instead of PowerShell/CIM. Parse the chipset name (e.g. "Apple M2").
- **Backend options** — Add Metal as a backend option for macOS. The macOS binary accepts `--backend metal`. Add detection via `backendAccepts()` (which already probes the binary).
- **VRAM monitoring** — On macOS, read unified memory stats via `sysctl hw.memsize` and `vm_stat` since Apple Silicon uses shared memory. No nvidia-smi equivalent needed.
- **Backend selection logic** — On `darwin`, default to Metal backend. Fall back to CPU if Metal probe fails.

### `README.md`
- Add macOS Quick Start section (`chmod +x start.sh && ./start.sh`)
- Add Apple Silicon to GPU compatibility matrix
- Note that only arm64 is supported (no Intel Mac binary from upstream)

### `.gitignore`
- Add `app/tools/node-mac/`
- Add `app/backend/mac/`

## Constraints

- No Homebrew dependency — portable Node.js is self-contained, same as Windows version
- Single macOS binary includes both Metal and CPU backends (no separate download)
- Frontend code (`app/frontend/`) requires no changes — it communicates with the same API
