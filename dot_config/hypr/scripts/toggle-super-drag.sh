#!/usr/bin/env bash
# Toggle SUPER+mouse:272 movewindow for Hyprland (writes state file)
CONFIG="$HOME/.config/hypr/hyprland.conf"
STATE_FILE="$HOME/.config/hypr/scripts/.super_drag_disabled"

# detect $mainMod (fallback SUPER)
MAINMOD=$(grep -E '^\s*\$mainMod\s*=' "$CONFIG" 2>/dev/null | head -n1 | sed -E 's/^\s*\$mainMod\s*=\s*//; s/\s*$//' || true)
if [ -z "$MAINMOD" ]; then MAINMOD="SUPER"; fi

BIND_KEY="mouse:272"
BIND_STR="${MAINMOD},${BIND_KEY}"
BIND_FULL="${MAINMOD},${BIND_KEY},movewindow"

unbind_move() { hyprctl keyword unbind "$BIND_STR" >/dev/null 2>&1 || true; }
bind_move()   { hyprctl keyword bindm  "$BIND_FULL" >/dev/null 2>&1 || true; }

if [ -f "$STATE_FILE" ]; then
  # currently disabled -> enable
  bind_move
  rm -f "$STATE_FILE"
  notify-send "Hyprland" "SUPER+drag: ACTIVADO"
else
  # currently enabled -> disable
  mkdir -p "$(dirname "$STATE_FILE")"
  echo "$BIND_FULL" > "$STATE_FILE"
  unbind_move
  notify-send "Hyprland" "SUPER+drag: DESACTIVADO"
fi

pkill -RTMIN+6 waybar || true
