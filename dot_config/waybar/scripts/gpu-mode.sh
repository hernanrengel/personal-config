#!/usr/bin/env bash
# Shows current GPU mode. Click cycles: hybrid -> integrated -> nvidia -> hybrid

if ! command -v envycontrol &>/dev/null; then
    exit 0
fi

MODE=$(envycontrol --query 2>/dev/null)

case "$MODE" in
    hybrid)     echo '{"text":"󰍺 Hybrid","tooltip":"GPU: Hybrid mode (iGPU renders, dGPU on demand)\nClick to switch → Integrated","class":"hybrid"}' ;;
    integrated) echo '{"text":"󰍹 Intel","tooltip":"GPU: Integrated only (battery saver)\nClick to switch → NVIDIA","class":"integrated"}' ;;
    nvidia)     echo '{"text":"󰾲 NVIDIA","tooltip":"GPU: Dedicated NVIDIA only\nClick to switch → Hybrid","class":"nvidia"}' ;;
esac
