#!/bin/bash

INTERNAL="eDP-1"
WALLPAPER="$HOME/Pictures/Wallpapers/wallpapersden.com_astronaut-with-jellyfish_2560x1440.jpg"
DELAY=1.5

set_primary_monitor() {
    EXTERNAL=$(hyprctl monitors -j | jq -r '.[] | select(.name != "'"$INTERNAL"'") | .name' | head -n 1)

    if [ -n "$EXTERNAL" ]; then
        hyprctl keyword monitor "$EXTERNAL,preferred,auto,1"
        hyprctl keyword monitor "$INTERNAL,disable"
    else
        hyprctl keyword monitor "$INTERNAL,preferred,auto,1"
    fi
}

start_swww_once() {
    if ! pgrep -x "swww-daemon" >/dev/null; then
        swww-daemon &
        for i in {1..20}; do
            if swww query &>/dev/null; then break; fi
            sleep 0.2
        done
    fi
}

apply_wallpaper() {
    sleep "$DELAY"
    swww img "$WALLPAPER" --transition-type fade --transition-fps 60
}

# --- Inicio ---
sleep 2
start_swww_once
set_primary_monitor
apply_wallpaper

# Escuchar cambios de monitor
hyprctl -j listen | jq -r 'select(.event == "monitoradded" or .event == "monitorremoved")' | while read -r _; do
    sleep 1
    set_primary_monitor
    apply_wallpaper
done
