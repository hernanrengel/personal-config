#!/usr/bin/env bash
# Waybar theme switcher — copies a theme's config+style into place and reloads.
# Usage: theme.sh <tui|brutalist|naked|editorial>
set -e

DIR="$HOME/.config/waybar"
THEMES_DIR="$DIR/themes"
THEME="${1:-}"

if [ -z "$THEME" ] || [ ! -d "$THEMES_DIR/$THEME" ]; then
    echo "Uso: theme.sh <nombre>"
    echo "Temas disponibles:"
    ls "$THEMES_DIR" | sed 's/^/  - /'
    exit 1
fi

cp "$THEMES_DIR/$THEME/config.jsonc" "$DIR/config.jsonc"
cp "$THEMES_DIR/$THEME/style.css"    "$DIR/style.css"

# --- fastfetch: recolorea el logo al acento de pywal ---
"$HOME/.config/fastfetch/recolor-logo.sh" >/dev/null 2>&1 || true
echo "$THEME" > "$HOME/.config/fastfetch/.current-theme"

killall waybar 2>/dev/null || true
pkill -x cava 2>/dev/null || true     # avoid orphaned cava visualizers
sleep 0.8
setsid nohup waybar >/tmp/waybar.log 2>&1 < /dev/null &
disown
sleep 1.5

if pgrep -x waybar >/dev/null; then
    ERRS=$(grep -icE 'error' /tmp/waybar.log || true)
    echo "✓ Tema aplicado: $THEME  (errores: $ERRS)"
else
    echo "✗ Waybar no arrancó — revisa /tmp/waybar.log"
fi
