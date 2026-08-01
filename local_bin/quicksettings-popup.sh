#!/usr/bin/env bash
if pgrep -f "quicksettings_popup.py" &>/dev/null; then
    pkill -f "quicksettings_popup.py"
else
    python3 ~/.local/bin/quicksettings_popup.py &
fi
