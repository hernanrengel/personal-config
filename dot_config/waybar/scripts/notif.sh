#!/usr/bin/env bash
# Waybar swaync notification module — bell + count, DND aware. Outputs JSON.
count=$(swaync-client -c 2>/dev/null); [ -z "$count" ] && count=0
dnd=$(swaync-client -D 2>/dev/null)

if [ "$dnd" = "true" ]; then
    icon="󰂛"; cls="dnd"
elif [ "$count" -gt 0 ] 2>/dev/null; then
    icon="󰂚"; cls="unread"
else
    icon="󰂚"; cls="idle"
fi

if [ "$count" -gt 0 ] 2>/dev/null; then text="$icon $count"; else text="$icon"; fi
printf '{"text":"%s","class":"%s","tooltip":"%s notificaciones · clic: panel · der: DND"}\n' "$text" "$cls" "$count"
