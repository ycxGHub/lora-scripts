#!/usr/bin/env bash
#
# Entry point for the lora-scripts RunPod image.
#
# This file is baked into the image (CMD ["/runpod-start.sh"]).
# Do NOT paste its contents into the RunPod Template's "Container Start
# Command" field — leave that field empty so the image's own CMD runs.
#
# 1. Link sd-models / output to a shared ComfyUI install (if present)
# 2. Hand off to the base image's own start.sh (SSH, JupyterLab, etc.)
# 3. Launch the SD-Trainer WebUI in the foreground

# --- Share models with ComfyUI ----------------------------------------------
# Override the ComfyUI location with the COMFYUI_DIR env var if it isn't
# /workspace/runSlim/ComfyUI.
COMFYUI_DIR="${COMFYUI_DIR:-/workspace/runSlim/ComfyUI}"
LORA_SCRIPTS_DIR=/app/lora-scripts

link_dir() {
    target="$1"
    link="$2"

    if [ ! -d "$target" ]; then
        return
    fi

    if [ -L "$link" ]; then
        # already a symlink, nothing to do
        return
    fi

    rm -rf "$link"
    ln -s "$target" "$link"
    echo "[runpod-start] Linked $link -> $target"
}

if [ -d "$COMFYUI_DIR/models" ]; then
    mkdir -p "$COMFYUI_DIR/models/checkpoints" "$COMFYUI_DIR/models/loras"
    link_dir "$COMFYUI_DIR/models/checkpoints" "$LORA_SCRIPTS_DIR/sd-models"
    link_dir "$COMFYUI_DIR/models/loras" "$LORA_SCRIPTS_DIR/output"
else
    echo "[runpod-start] ComfyUI dir not found at $COMFYUI_DIR, skipping model sharing"
fi

# --- Hand off to the base image's own start.sh (SSH, JupyterLab, etc.) ------
if [ -f /start.sh ]; then
    echo "[runpod-start] Launching base image start.sh in background"
    bash /start.sh &
fi

# --- SD-Trainer WebUI ---------------------------------------------------------
echo "[runpod-start] Starting SD-Trainer WebUI on :28000"
cd "$LORA_SCRIPTS_DIR" || exit 1
exec python gui.py --listen --port 28000
