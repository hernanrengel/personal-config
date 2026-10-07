#!/usr/bin/env bash
# refresh-bar.sh — Refreshes whichever bar (AGS or Waybar) is currently running.

if pgrep -f 'gjs.*[a]gs' >/dev/null; then
    echo "Refrescando AGS..."
    pkill -f 'gjs.*[a]gs' || true
    sleep 0.6
    setsid nohup ags run >/tmp/ags.log 2>&1 < /dev/null &
    disown
elif pgrep -x waybar >/dev/null; then
    echo "Refrescando Waybar..."
    killall -9 waybar || true
    sleep 0.5
    setsid nohup waybar >/tmp/waybar.log 2>&1 < /dev/null &
    disown
else
    # Si ninguno está corriendo, inicia AGS por defecto
    echo "Iniciando AGS por defecto..."
    setsid nohup ags run >/tmp/ags.log 2>&1 < /dev/null &
    disown
fi
