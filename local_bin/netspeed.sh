#!/usr/bin/env bash
# Reads /proc/net/dev, diffs against last saved reading, outputs ↓/↑ speed
CACHE="/tmp/netspeed_prev"

# Sum bytes across all non-loopback interfaces
read_bytes() {
    awk '
        NR>2 && $1 !~ /^lo:/ {
            rx += $2; tx += $10
        }
        END { print rx, tx }
    ' /proc/net/dev
}

fmt() {
    local b=$1
    if   [ "$b" -ge 1048576 ]; then printf "%.1fM" "$(echo "scale=1; $b/1048576" | bc)"
    elif [ "$b" -ge 1024 ];    then printf "%.0fK" "$(echo "scale=0; $b/1024"    | bc)"
    else printf "%dB" "$b"
    fi
}

now=$(date +%s%N)
read -r rx tx <<< "$(read_bytes)"

if [ -f "$CACHE" ]; then
    read -r prev_rx prev_tx prev_time < "$CACHE"
    dt_ns=$(( now - prev_time ))
    dt_s=$(echo "scale=3; $dt_ns/1000000000" | bc)
    drx=$(echo "scale=0; ($rx - $prev_rx) / $dt_s / 1" | bc 2>/dev/null || echo 0)
    dtx=$(echo "scale=0; ($tx - $prev_tx) / $dt_s / 1" | bc 2>/dev/null || echo 0)
    [ "$drx" -lt 0 ] 2>/dev/null && drx=0
    [ "$dtx" -lt 0 ] 2>/dev/null && dtx=0
    echo "↓ $(fmt $drx) ↑ $(fmt $dtx)"
else
    echo "↓ -- ↑ --"
fi

echo "$rx $tx $now" > "$CACHE"
