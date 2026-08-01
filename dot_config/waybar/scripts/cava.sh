#!/usr/bin/env bash
# Waybar cava visualizer — streams animated, spaced-out bars to a custom module.
# Maps cava's 0-7 ascii levels to block glyphs; the bar delimiter becomes a
# space so the bars read as thin, separated lines.

CAVA_BIN="/usr/sbin/cava"
command -v cava >/dev/null 2>&1 && CAVA_BIN="$(command -v cava)"

bar="▁▂▃▄▅▆▇█"
dict="s/;//g"           # no separation -> bars adjacent (smooth continuous wave)
i=0
while [ $i -lt ${#bar} ]; do
    dict="${dict};s/$i/${bar:$i:1}/g"
    i=$((i + 1))
done

config_file="$(mktemp /tmp/waybar_cava.XXXX)"
cat > "$config_file" <<EOF
[general]
bars = 24
framerate = 60
sensitivity = 100

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7

[smoothing]
monstercat = 1
waves = 0
gravity = 120
noise_reduction = 0.35
EOF

trap 'rm -f "$config_file"' EXIT
# Map levels -> glyphs, then wrap each frame in a Pango span that adds a
# ~1px gap between bars via letter_spacing (sub-cell separation).
"$CAVA_BIN" -p "$config_file" \
    | sed -u "$dict" \
    | sed -u 's|.*|<span letter_spacing="1024">&</span>|'
