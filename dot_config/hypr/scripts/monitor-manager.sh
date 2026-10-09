#!/bin/bash

INTERNAL="eDP-1"
WALLPAPER="$HOME/Pictures/Wallpapers/wallpapersden.com_astronaut-with-jellyfish_2560x1440.jpg"
DELAY=1.5
TOGGLE_SCRIPT="$HOME/.config/hypr/scripts/toggle-internal-monitor.sh"

echo "Monitor manager started."

start_awww_once() {
    if ! pgrep -x "awww-daemon" >/dev/null; then
        echo "Starting awww-daemon..."
        awww-daemon &
        sleep 0.8
    fi
}

apply_wallpaper() {
    sleep "$DELAY"
    # Reusar el fondo actual (el de random-wallpaper.sh) en el monitor nuevo; fallback fijo
    local current
    current="$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1)"
    [ -f "$current" ] || current="$WALLPAPER"
    echo "Applying wallpaper: $current"
    awww img "$current" --transition-type fade --transition-fps 60
}

# --- Inicio ---
# Sin apply_wallpaper aquí: awww-daemon restaura de su caché el último fondo,
# que es el mismo que mostró el login (SDDM), así la entrada no cambia de imagen.
sleep 2
start_awww_once

# Escuchar cambios de monitor usando socat apuntando al socket oficial de Hyprland
while true; do
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
        echo "Connecting to Hyprland event socket at $SOCKET_PATH..."
        if [ -S "$SOCKET_PATH" ]; then
            socat -u "UNIX-CONNECT:$SOCKET_PATH" - | while read -r line; do
                echo "Event: $line"
                if [[ "$line" == "monitorremoved>>"* ]]; then
                    echo "Monitor removal detected. Waiting 1s..."
                    sleep 1
                    # Asegurar que el monitor interno se reactive si no hay pantallas externas
                    if [ -f "$TOGGLE_SCRIPT" ]; then
                        echo "Running $TOGGLE_SCRIPT --ensure..."
                        "$TOGGLE_SCRIPT" --ensure
                    fi
                    apply_wallpaper
                elif [[ "$line" == "monitoradded>>"* ]]; then
                    echo "Monitor addition detected. Reloading monitor layouts..."
                    hyprctl reload
                    sleep 1
                    apply_wallpaper
                fi
            done
        else
            echo "Socket file $SOCKET_PATH not found or not a socket."
        fi
    else
        echo "HYPRLAND_INSTANCE_SIGNATURE is not set."
    fi
    sleep 2
done
