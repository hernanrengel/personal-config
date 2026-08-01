#!/usr/bin/env bash
# Cycles GPU mode: hybrid -> integrated -> nvidia -> hybrid
# Requires reboot to take effect — shows notification

MODE=$(envycontrol --query 2>/dev/null)

case "$MODE" in
    hybrid)     NEXT="integrated" ;;
    integrated) NEXT="nvidia" ;;
    nvidia)     NEXT="hybrid" ;;
    *)          NEXT="hybrid" ;;
esac

sudo envycontrol -s "$NEXT" && \
    notify-send "GPU Mode" "Switched to $NEXT — reboot required" --icon=computer
