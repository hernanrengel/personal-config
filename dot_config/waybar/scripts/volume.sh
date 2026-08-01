#!/bin/bash
volume=$(pamixer --get-volume)
muted=$(pamixer --get-mute)

if [ "$muted" = "true" ]; then
    echo "{\"text\": \" Muted\", \"tooltip\": \"Volume muted\"}"
else
    echo "{\"text\": \" $volume%\", \"tooltip\": \"Volume at $volume%\"}"
fi
