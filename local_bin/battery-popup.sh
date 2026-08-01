#!/usr/bin/env bash
PIDFILE="/tmp/battery_popup.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
    kill "$(cat $PIDFILE)"
    rm -f "$PIDFILE"
else
    python3 ~/.local/bin/battery_popup.py &
    echo $! > "$PIDFILE"
fi
