#!/usr/bin/env bash
CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity)
STATUS=$(cat /sys/class/power_supply/BAT0/status)

[[ "$STATUS" == "Charging" || "$STATUS" == "Full" ]] && exit 0

if (( CAPACITY <= 10 )); then
    notify-send -u critical "Battery Critical" "${CAPACITY}% — plug in now" --icon=battery-caution
elif (( CAPACITY <= 20 )); then
    notify-send -u normal "Battery Low" "${CAPACITY}% remaining" --icon=battery-low
fi
