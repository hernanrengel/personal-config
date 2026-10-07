#!/usr/bin/env bash
# Cycles GPU mode

if command -v supergfxctl &>/dev/null; then
    MODE=$(supergfxctl -g 2>/dev/null)
    case "$MODE" in
        Hybrid)     NEXT="Integrated" ;;
        Integrated) NEXT="AsusMuxDgpu" ;;
        AsusMuxDgpu) NEXT="Hybrid" ;;
        *)          NEXT="Hybrid" ;;
    esac
    
    supergfxctl -m "$NEXT" && \
        notify-send "GPU Mode" "Switched to $NEXT. Please re-login for full effect." --icon=computer
    exit 0
fi

if command -v envycontrol &>/dev/null; then
    MODE=$(envycontrol --query 2>/dev/null)
    case "$MODE" in
        hybrid)     NEXT="integrated" ;;
        integrated) NEXT="nvidia" ;;
        nvidia)     NEXT="hybrid" ;;
        *)          NEXT="hybrid" ;;
    esac

    sudo envycontrol -s "$NEXT" && \
        notify-send "GPU Mode" "Switched to $NEXT — reboot required" --icon=computer
    exit 0
fi
