#!/usr/bin/env bash
set -euo pipefail

FORCE=false
DISCOVER=false
for arg in "$@"; do
    [[ "$arg" == "--force" ]] && FORCE=true
    [[ "$arg" == "--discover" ]] && DISCOVER=true
done

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
# Curaduría: si este dir tiene imágenes, son la ÚNICA fuente (mood/paleta coherente).
# Vacíalo o usa --discover para volver a bajar random.
CURATED_DIR="$WALLPAPER_DIR/curated"
CACHE_DIR="$HOME/.cache/minimalistic-wallpapers"
INDEX_FILE="$CACHE_DIR/index.txt"
INDEX_MAX_AGE=86400  # refresh index once per day
RAW_BASE="https://raw.githubusercontent.com/DenverCoder1/minimalistic-wallpaper-collection/main/images"
TREES_API="https://api.github.com/repos/DenverCoder1/minimalistic-wallpaper-collection/git/trees/main?recursive=1"
MIN_WIDTH=800
MAX_TRIES=5

mkdir -p "$CACHE_DIR"

# Fetch or refresh the list of image filenames from the repo (one API call, cached 24h)
refresh_index() {
    curl -sf --max-time 15 "$TREES_API" 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('tree', []):
    p = item.get('path', '')
    if p.startswith('images/') and p.lower().endswith(('.jpg','.jpeg','.png','.webp')):
        print(p[len('images/'):])
" > "$INDEX_FILE"
}

index_needs_refresh() {
    [ ! -f "$INDEX_FILE" ] && return 0
    [ ! -s "$INDEX_FILE" ] && return 0
    local age=$(( $(date +%s) - $(stat -c %Y "$INDEX_FILE") ))
    [ "$age" -gt "$INDEX_MAX_AGE" ] && return 0
    return 1
}

is_valid_image() {
    local f="$1"
    [ -f "$f" ] || return 1
    file "$f" | grep -qiE 'image|jpeg|png|webp' || return 1
    local w
    w=$(identify -format "%w" "$f[0]" 2>/dev/null || echo 0)
    [ "$w" -ge "$MIN_WIDTH" ]
}

download_random() {
    if index_needs_refresh; then
        refresh_index || true
    fi

    [ -s "$INDEX_FILE" ] || return 1

    local tries=0
    while [ "$tries" -lt "$MAX_TRIES" ]; do
        local filename
        filename=$(shuf -n1 "$INDEX_FILE")
        [ -z "$filename" ] && { tries=$((tries+1)); continue; }

        local dest="$CACHE_DIR/$filename"

        if [ -f "$dest" ] && is_valid_image "$dest"; then
            echo "$dest"
            return 0
        fi

        curl -sf --max-time 30 -L -o "$dest" "$RAW_BASE/$filename" \
            || { rm -f "$dest"; tries=$((tries+1)); continue; }

        if is_valid_image "$dest"; then
            echo "$dest"
            return 0
        else
            rm -f "$dest"
        fi

        tries=$((tries+1))
    done

    return 1
}

pick_local() {
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
        -not -path "*/.git/*" | shuf -n1
}

pick_curated() {
    [ -d "$CURATED_DIR" ] || return 1
    find "$CURATED_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n1
}

# Si hay live wallpaper activo (mpvpaper corriendo), no interrumpir (salvo --force)
if pgrep -x mpvpaper >/dev/null 2>&1; then
    if $FORCE; then
        pkill mpvpaper 2>/dev/null || true
        sleep 0.3
    else
        exit 0
    fi
fi

pgrep -x awww-daemon >/dev/null 2>&1 || { awww-daemon & sleep 0.8; }

# Curado primero (mood coherente); --discover fuerza bajar uno nuevo
if ! $DISCOVER && PIC="$(pick_curated)" && [ -n "$PIC" ]; then
    :
else
    PIC="$(download_random 2>/dev/null)" || PIC="$(pick_local)"
fi

[ -z "$PIC" ] && { echo "No wallpaper found"; exit 1; }

# Variedad pero suave: lista curada SIN 'none'/'simple' (cortes secos) y con
# --transition-step bajo para que el barrido tenga borde difuso, no duro.
TRANSITIONS=(fade grow wipe wave)
T="${TRANSITIONS[RANDOM % ${#TRANSITIONS[@]}]}"
awww img "$PIC" \
  --transition-type="$T" \
  --transition-duration=2 \
  --transition-fps=60 \
  --transition-step=20

wal -n -q -i "$PIC" 2>&1 | grep -v "convert command is deprecated" >&2 || true

# Bordes de Hyprland desde la paleta pywal:
#  - escribe el archivo cacheado (lo sourcea hyprland.conf al reiniciar)
#  - y lo aplica en vivo con hyprctl (sin reload completo)
if [ -f "$HOME/.cache/wal/colors.sh" ]; then
    # colors.sh (pywal) hace `export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS ..."`.
    # Con `set -u` y FZF_DEFAULT_OPTS sin definir (caso normal desde Hyprland/
    # systemd), sourcearlo aborta el script ANTES de recargar waybar. Blindarlo.
    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-}"
    set +u
    . "$HOME/.cache/wal/colors.sh"
    set -u
    cat > "$HOME/.cache/wal/colors-hyprland.conf" <<EOF
general {
    col.active_border = rgba(${color4#\#}ff) rgba(${color5#\#}ff) rgba(${color6#\#}ff) 45deg
    col.inactive_border = rgba(${color0#\#}aa)
}
EOF
    hyprctl keyword general:col.active_border "rgba(${color4#\#}ff) rgba(${color5#\#}ff) rgba(${color6#\#}ff) 45deg" >/dev/null 2>&1 || true
    hyprctl keyword general:col.inactive_border "rgba(${color0#\#}aa)" >/dev/null 2>&1 || true
fi

# Recolorea el logo de fastfetch al acento de la nueva paleta pywal
"$HOME/.config/fastfetch/recolor-logo.sh" >/dev/null 2>&1 || true

# waybar usa paleta NEUTRA estática — NO se recarga al cambiar wallpaper
# (evita flicker de barra + reflow de ventanas cada hora).
swaync-client --reload-css 2>/dev/null || true
kitty @ --to unix:/tmp/kitty set-colors --all "$HOME/.cache/wal/colors-kitty.conf" 2>/dev/null || true
