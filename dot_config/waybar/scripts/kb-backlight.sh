#!/usr/bin/env bash
SYSFS="/sys/class/leds/asus::kbd_backlight/brightness"
LEVEL=$(cat "$SYSFS" 2>/dev/null)

case "$LEVEL" in
    0) echo '{"text":"󰌹 off","tooltip":"Keyboard backlight: off — Click → low","class":"off"}' ;;
    1) echo '{"text":"󰌹 low","tooltip":"Keyboard backlight: low — Click → med","class":"low"}' ;;
    2) echo '{"text":"󰌹 med","tooltip":"Keyboard backlight: med — Click → high","class":"med"}' ;;
    3) echo '{"text":"󰌹 high","tooltip":"Keyboard backlight: high — Click → off","class":"high"}' ;;
    *) exit 0 ;;
esac
