#!/usr/bin/env bash
SYSFS="/sys/class/leds/asus::kbd_backlight/brightness"
LEVEL=$(cat "$SYSFS" 2>/dev/null)
NEXT=$(( (LEVEL + 1) % 4 ))
sudo /usr/local/bin/kbd-backlight-set "$NEXT"
