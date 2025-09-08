#!/bin/bash
set -e

# --- Share models with ComfyUI ----------------------------------------------
# If a ComfyUI install is present (e.g. on a shared network volume), point
# lora-scripts' model/output dirs at ComfyUI's so checkpoints/loras are shared.
# Override the ComfyUI location with COMFYUI_DIR if it isn't /workspace/ComfyUI.
COMFYUI_DIR="${COMFYUI_DIR:-/workspace/runSlim/ComfyUI}"
LORA_SCRIPTS_DIR=/app/lora-scripts

link_dir() {
    local target="$1" link="$2"
    if [ -d "$target" ] && [ ! -L "$link" ]; then
        rm -rf "$link"
        ln -s "$target" "$link"
        echo "Linked $link -> $target"
    fi
}

if [ -d "$COMFYUI_DIR/models" ]; then
    mkdir -p "$COMFYUI_DIR/models/checkpoints" "$COMFYUI_DIR/models/loras"
    link_dir "$COMFYUI_DIR/models/checkpoints" "$LORA_SCRIPTS_DIR/sd-models"
    link_dir "$COMFYUI_DIR/models/loras" "$LORA_SCRIPTS_DIR/output"
fi

# --- Hand off to RunPod's built-in start.sh (SSH, JupyterLab, etc.) ---------
# Run it in the background so we can still launch the WebUI in this script.
if [ -f /start.sh ]; then
    /start.sh &
fi

# --- SD-Trainer WebUI --------------------------------------------------------
cd /app/lora-scripts
exec python gui.py --listen --port 28000
