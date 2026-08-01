#!/usr/bin/env bash
# Recolorea el line-art de fastfetch al color de acento de pywal.
# Uso:
#   recolor-logo.sh            -> usa ~/.cache/wal/colors (línea $ACCENT_LINE)
#   recolor-logo.sh "#rrggbb"  -> fuerza un color
set -euo pipefail

FF="$HOME/.config/fastfetch"
BASE="$FF/logo_base.png"      # forma inmutable (line-art con alpha)
OUT="$FF/logo_active.png"     # lo que usa fastfetch (config -> logo_active.png)
COLORS="$HOME/.cache/wal/colors"
ACCENT_LINE=2                 # color1=línea2  (color4=5, color7/fg=8). Cámbialo a gusto.

[ -f "$BASE" ] || exit 0

if [ -n "${1:-}" ]; then
    COLOR="$1"
elif [ -f "$COLORS" ]; then
    COLOR="$(sed -n "${ACCENT_LINE}p" "$COLORS")"
else
    COLOR="#c9c4ec"
fi
[ -n "$COLOR" ] || COLOR="#c9c4ec"

# Garantía de legibilidad: si el acento sale muy oscuro (luma < $MIN_LUMA),
# le sube el piso de luminosidad en HSL conservando el tono. Acentos ya
# claros se dejan intactos.
MIN_LUMA=90      # umbral 0-255 para considerar "muy oscuro"
FLOOR_L=60       # piso de lightness HSL (%) al rescatar
LUMA="$(magick -size 1x1 xc:"$COLOR" -colorspace Gray -format '%[fx:int(mean*255)]' info: 2>/dev/null || echo 255)"
if [ "$LUMA" -lt "$MIN_LUMA" ] 2>/dev/null; then
    COLOR="$(magick -size 1x1 xc:"$COLOR" -alpha off -colorspace HSL \
        -channel B -evaluate max ${FLOOR_L}% +channel \
        -colorspace sRGB -format '%[pixel:p{0,0}]' info: 2>/dev/null || echo "$COLOR")"
fi

rm -f "$OUT"   # importante: si fuese symlink, escribir a través corrompería la base
magick "$BASE" -channel RGB -fill "$COLOR" -colorize 100 +channel "$OUT"
