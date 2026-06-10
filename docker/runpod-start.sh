#!/usr/bin/env bash
#
# Entry point for the lora-scripts RunPod image.
#
# This file is baked into the image (CMD ["/runpod-start.sh"]).
# Do NOT paste its contents into the RunPod Template's "Container Start
# Command" field — leave that field empty so the image's own CMD runs.
#
# 1. Move the app onto the persistent volume on first boot
# 2. Link sd-models / output to a shared ComfyUI install (if present)
# 3. Hand off to the base image's own start.sh (SSH, JupyterLab, etc.)
# 4. Launch the SD-Trainer WebUI in the foreground

IMAGE_APP_DIR=/app/lora-scripts
PERSIST_ROOT="${PERSIST_ROOT:-/workspace}"
APP_DIR="$PERSIST_ROOT/lora-scripts"

# --- Move app to persistent volume on first boot -----------------------------
if [ -d "$PERSIST_ROOT" ]; then
    if [ ! -e "$APP_DIR" ]; then
        echo "[runpod-start] First boot: copying app to $APP_DIR (this may take a while)"
        cp -a "$IMAGE_APP_DIR" "$APP_DIR"
    else
        echo "[runpod-start] Using existing app at $APP_DIR"
    fi
else
    echo "[runpod-start] $PERSIST_ROOT not mounted, running from $IMAGE_APP_DIR (NOT persistent)"
    APP_DIR="$IMAGE_APP_DIR"
fi

# --- Share models with ComfyUI ----------------------------------------------
# Override the ComfyUI location with the COMFYUI_DIR env var if needed.
COMFYUI_DIR="${COMFYUI_DIR:-$PERSIST_ROOT/runpod-slim/ComfyUI}"

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
    mkdir -p "$COMFYUI_DIR/models/checkpoints" "$COMFYUI_DIR/models/loras" "$APP_DIR/output"
    link_dir "$COMFYUI_DIR/models/checkpoints" "$APP_DIR/sd-models/comfyui"
    link_dir "$APP_DIR/output" "$COMFYUI_DIR/models/loras/lora-scripts"
else
    echo "[runpod-start] ComfyUI dir not found at $COMFYUI_DIR, skipping model sharing"
fi

# --- Hand off to the base image's own start.sh (SSH, JupyterLab, etc.) ------
if [ -f /start.sh ]; then
    echo "[runpod-start] Launching base image start.sh in background"
    bash /start.sh &
fi

# --- SD-Trainer WebUI ---------------------------------------------------------
echo "[runpod-start] Starting SD-Trainer WebUI on :28000 from $APP_DIR"
cd "$APP_DIR" || exit 1
exec python gui.py --listen --port 28000 --skip-prepare-environment
