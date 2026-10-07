#!/usr/bin/env bash
# Shows current GPU mode.

if command -v supergfxctl &>/dev/null; then
    MODE=$(supergfxctl -g 2>/dev/null)
    case "$MODE" in
        Hybrid)     echo '{"text":"󰍺 Hybrid","tooltip":"GPU: Hybrid mode (iGPU renders, dGPU on demand)\nClick to cycle","class":"hybrid"}' ;;
        Integrated) echo '{"text":"󰍹 AMD","tooltip":"GPU: Integrated only (battery saver)\nClick to cycle","class":"integrated"}' ;;
        AsusMuxDgpu) echo '{"text":"󰾲 NVIDIA","tooltip":"GPU: Dedicated NVIDIA only\nClick to cycle","class":"nvidia"}' ;;
        Compute)    echo '{"text":"󰾲 Compute","tooltip":"GPU: Compute mode\nClick to cycle","class":"hybrid"}' ;;
        *)          echo '{"text":"󰍺 '"$MODE"'","class":"hybrid"}' ;;
    esac
    exit 0
fi

if command -v envycontrol &>/dev/null; then
    MODE=$(envycontrol --query 2>/dev/null)
    case "$MODE" in
        hybrid)     echo '{"text":"󰍺 Hybrid","tooltip":"GPU: Hybrid mode (iGPU renders, dGPU on demand)\nClick to cycle","class":"hybrid"}' ;;
        integrated) echo '{"text":"󰍹 Intel","tooltip":"GPU: Integrated only (battery saver)\nClick to cycle","class":"integrated"}' ;;
        nvidia)     echo '{"text":"󰾲 NVIDIA","tooltip":"GPU: Dedicated NVIDIA only\nClick to cycle","class":"nvidia"}' ;;
    esac
    exit 0
fi

echo '{"text":"󰍺 GPU","class":"hybrid"}'
