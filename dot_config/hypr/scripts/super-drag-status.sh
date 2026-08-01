#!/usr/bin/env bash
STATE_FILE="$HOME/.config/hypr/scripts/.super_drag_disabled"
# Output short label for waybar. Adjust icons/text as you prefer.
if [ -f "$STATE_FILE" ]; then
  # disabled
  echo "󰍾"
else
  echo "󰍽"
fi
