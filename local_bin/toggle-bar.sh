#!/usr/bin/env bash
# toggle-bar.sh — Intercambia entre Waybar y AGS

if pgrep -f 'gjs.*[a]gs' >/dev/null; then
    echo "Cerrando AGS e iniciando Waybar..."
    pkill -f 'gjs.*[a]gs' || true
    sleep 0.8
    # Inicia Waybar en segundo plano
    setsid nohup waybar >/tmp/waybar.log 2>&1 < /dev/null &
    disown
    echo "✓ Waybar activado."
elif pgrep -x waybar >/dev/null; then
    echo "Cerrando Waybar e iniciando AGS..."
    pkill -x waybar || true
    sleep 0.8
    # Inicia AGS en segundo plano
    setsid nohup ags run >/tmp/ags.log 2>&1 < /dev/null &
    disown
    echo "✓ AGS activado."
else
    # Si ninguno está corriendo, inicia Waybar por defecto
    echo "Iniciando Waybar por defecto..."
    setsid nohup waybar >/tmp/waybar.log 2>&1 < /dev/null &
    disown
fi
