#!/usr/bin/env bash
# Waybar media play/pause icon — reflects current player status.
s=$(playerctl --ignore-player=mpv status 2>/dev/null)
[ "$s" = "Playing" ] && echo "󰏤" || echo "󰐊"
