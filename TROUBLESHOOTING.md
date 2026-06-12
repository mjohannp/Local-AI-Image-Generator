# Troubleshooting Guide

This document covers known issues, common error messages, and platform-specific troubleshooting steps for Local AI Image Generator.

---

## Table of Contents

- [General Issues](#general-issues)
- [Windows-Specific Issues](#windows-specific-issues)
- [macOS-Specific Issues](#macos-specific-issues)
- [Linux-Specific Issues](#linux-specific-issues)
- [Backend-Specific Issues](#backend-specific-issues)
- [Model-Related Issues](#model-related-issues)

---

## General Issues

### Port Already in Use

**Error:** "Port 1420 is already in use" or "Backend port 8080 is busy"

**Solution:**
- The frontend automatically tries port 1420. The backend tries 8080, then falls back to ports 28088-28120.
- Close other applications using these ports, or let the app auto-select a different backend port.

### Models Not Appearing

**Possible Causes:**
1. Model files are in the wrong directory
2. Model files have incorrect file extensions
3. Models are still downloading (check `.part` files)

**Solution:**
- Ensure models are in `app/models/`
- Supported formats: `.safetensors`, `.gguf`, `.ckpt`
- Wait for downloads to complete (remove any `.part` or `.tmp` files if download failed)

---

## Windows-Specific Issues

### CUDA Backend Not Available

**Error:** "CUDA GPU unavailable: Installed, but CUDA backend validation failed."

**Possible Causes:**
1. Nvidia driver not installed or outdated
2. CUDA runtime not available
3. Graphics card not recognized

**Solution:**
1. Update Nvidia drivers from https://www.nvidia.com/Download/index.aspx
2. Run `nvidia-smi` in Command Prompt to verify GPU detection
3. If issues persist, try Vulkan backend instead

### Vulkan Backend Issues

**Error:** "Vulkan GPU unavailable: Installed, but this binary did not register a Vulkan backend."

**Solution:**
1. Update GPU drivers (AMD/Intel)
2. Ensure Vulkan runtime is installed
3. Try CPU backend as fallback

---

## macOS-Specific Issues

### Metal Backend Not Available (Critical Issue)

**Error:** "Metal GPU unavailable: Installed, but Metal backend validation failed."

**Symptoms:**
- Backend binary exists and launches
- GPU is detected (e.g., M1/M2/M3)
- But backend fails with: `[ERROR] backend config failed: backend 'metal' was not found`

**Root Cause:**
The pre-compiled `stable-diffusion.cpp` binary from GitHub releases has a **known issue** where the Metal backend is not properly registered/compiled in the release builds. This is a bug in the upstream binary, not in this application.

**Current Status:**
- Issue tracked in: [stable-diffusion.cpp Issue #108](https://github.com/leejet/stable-diffusion.cpp/issues/108) and [Issue #1040](https://github.com/leejet/stable-diffusion.cpp/issues/1040)
- The pre-compiled macOS arm64 binary from `leejet/stable-diffusion.cpp` releases has broken Metal backend support
- This affects all Apple Silicon Macs (M1/M2/M3/M4) regardless of RAM size

**Workarounds:**

**Option 1: Use CPU Backend (Recommended for Now)**
- CPU backend works reliably on all Macs
- Slower than GPU, but stable and functional
- Select "CPU" in the backend settings dropdown

**Option 2: Build Your Own Metal Backend**
If you need GPU acceleration, you can compile the backend yourself:

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Clone stable-diffusion.cpp
cd /Users/michael/Projects/Local-AI-Image-Generator/app/tools
git clone https://github.com/leejet/stable-diffusion.cpp
cd stable-diffusion.cpp

# Build with Metal support
mkdir build && cd build
cmake .. -DSD_METAL=ON -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)

# Copy the compiled binary
cp sd /Users/michael/Projects/Local-AI-Image-Generator/app/backend/mac/sd
cp *.dylib /Users/michael/Projects/Local-AI-Image-Generator/app/backend/mac/
```

**Note:** Even self-compilation may not resolve the issue due to known bugs in the Metal backend implementation (as of June 2025). Refer to the linked issues above for the latest status.

**Option 3: Alternative Solutions**
Consider using other Stable Diffusion implementations with better Metal support:
- Automatic1111 WebUI (experimental Metal support)
- Diffusers with MPS (Metal Performance Shaders) backend

**RAM Considerations:**
- While Metal backend issues exist regardless of RAM, Stable Diffusion performs best with 32GB+ unified memory
- 16GB Macs may experience memory pressure with large models
- The error message "backend not found" is distinct from "not enough memory" — the former indicates the backend compilation issue

### Application Won't Start on macOS

**Error:** "Permission denied" when running `./start.sh`

**Solution:**
```bash
chmod +x start.sh
./start.sh
```

---

## Linux-Specific Issues

### Vulkan Backend Not Available

**Error:** "Vulkan GPU unavailable: Installed, but this binary did not register a Vulkan backend."

**Solution:**
1. Install Vulkan drivers for your GPU
2. For AMD/Intel: `sudo apt install mesa-vulkan-drivers` (Debian/Ubuntu)
3. For Nvidia: Install latest proprietary drivers
4. Verify with: `vulkaninfo`

### Permission Denied on Binary

**Error:** "Permission denied" when running backend

**Solution:**
```bash
chmod +x app/backend/linux/sd-vulkan
```

---

## Backend-Specific Issues

### Backend Exits Immediately

**Error:** Backend starts but exits with code 1

**Possible Causes:**
1. Model file corrupted or incomplete
2. Not enough RAM/VRAM
3. Unsupported model format

**Solution:**
1. Verify model file size (should be > 128MB for complete models)
2. Try a different model
3. Reduce image resolution or steps
4. Try CPU backend

### "Model load blocked" Error

**Error:** Backend refuses to load the model

**Common Causes:**
1. Incomplete download (check `.part` files)
2. Corrupted model file
3. Multi-file GGUF without required components

**Solution:**
1. Delete and re-download the model
2. Verify file integrity (size should match expected)
3. For GGUF files, ensure all required components are present

---

## Model-Related Issues

### GGUF Model Not Working

**Error:** "new_sd_ctx_t failed" or "could not be loaded as a single checkpoint"

**Cause:**
Some GGUF files are diffusion-only components that require separate VAE/text encoder files.

**Solution:**
- Use recommended SD 1.5 or SDXL Safetensors checkpoints instead
- Or ensure you have complete multi-file GGUF sets with all components

### Model Too Small Error

**Error:** Model file is too small to be complete

**Solution:**
- Download is incomplete — delete and retry
- Minimum size for image models is ~128MB

---

## Getting Help

If you encounter issues not covered here:

1. **Check the logs:** Look for error messages in the terminal/console output
2. **Search existing issues:** Check [GitHub Issues](https://github.com/mjohannp/Local-AI-Image-Generator/issues)
3. **Create a new issue:** Include:
   - Your OS and version
   - GPU/CPU specs
   - Exact error message
   - Steps to reproduce

---

## External Resources

- **stable-diffusion.cpp:** https://github.com/leejet/stable-diffusion.cpp
- **Stable Diffusion Models:** https://civitai.com/ or https://huggingface.co/
- **Model Formats Guide:** https://github.com/PatrickHopt/stable-diffusion-cpp-guide
