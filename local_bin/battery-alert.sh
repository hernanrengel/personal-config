#!/usr/bin/env bash
# BAT0 en la laptop vieja, BAT1 en la G14: usar la primera batería que exista
BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
[ -z "$BAT" ] && exit 0
CAPACITY=$(cat "$BAT/capacity")
STATUS=$(cat "$BAT/status")

[[ "$STATUS" == "Charging" || "$STATUS" == "Full" ]] && exit 0

if (( CAPACITY <= 10 )); then
    notify-send -u critical "Battery Critical" "${CAPACITY}% — plug in now" --icon=battery-caution
elif (( CAPACITY <= 20 )); then
    notify-send -u normal "Battery Low" "${CAPACITY}% remaining" --icon=battery-low
fi
