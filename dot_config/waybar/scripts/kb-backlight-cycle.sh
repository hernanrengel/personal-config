#!/usr/bin/env bash
# Script para rotar el brillo del teclado (0, 1, 2, 3) usando brightnessctl

SYSFS="/sys/class/leds/asus::kbd_backlight/brightness"
if [ -f "$SYSFS" ]; then
    LEVEL=$(cat "$SYSFS" 2>/dev/null)
    NEXT=$(( (LEVEL + 1) % 4 ))
    brightnessctl --device='asus::kbd_backlight' set "$NEXT" > /dev/null
fi
