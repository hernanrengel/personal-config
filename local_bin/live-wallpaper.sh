#!/usr/bin/env bash
set -euo pipefail

LIVE_DIR="$HOME/Pictures/live_wallpapers"
LIVE_THEME="$HOME/.config/wal/live-theme.css"
LIVE_THEME_KITTY="$HOME/.config/wal/live-theme-kitty.conf"
WAL_WAYBAR="$HOME/.cache/wal/colors-waybar.css"
WAL_KITTY="$HOME/.cache/wal/colors-kitty.conf"

[ -d "$LIVE_DIR" ] || { echo "Directorio $LIVE_DIR no existe"; exit 1; }

VIDEO=$(find "$LIVE_DIR" -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.avi" \) | shuf -n1)

[ -z "$VIDEO" ] && { echo "No hay videos en $LIVE_DIR"; exit 1; }

# Stop static wallpaper daemons
pkill awww 2>/dev/null || true
pkill mpvpaper 2>/dev/null || true
sleep 0.4

# Start mpvpaper — no audio, loop, high quality rendering
mpvpaper -f -o "no-audio loop hwdec=auto profile=gpu-hq scale=ewa_lanczos cscale=ewa_lanczos panscan=1.0" '*' "$VIDEO"

# Apply fixed live theme instantly (no pywal, no ffmpeg)
cp "$LIVE_THEME" "$WAL_WAYBAR"
cp "$LIVE_THEME_KITTY" "$WAL_KITTY"
pkill -SIGUSR2 waybar || true
swaync-client --reload-css 2>/dev/null || true
kitty @ --to unix:/tmp/kitty set-colors --all "$WAL_KITTY" 2>/dev/null || true

echo "Live wallpaper: $(basename "$VIDEO")"
