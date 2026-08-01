#!/usr/bin/env bash
set -euo pipefail

INTERNAL="eDP-1"
EXPLICIT_MODE="1920x1080@60"
EXPLICIT_POS="0x0"
EXPLICIT_SCALE="1"
NOTIFY_BIN="$(command -v notify-send || true)"
BRIGHT_BIN="$(command -v brightnessctl || true)"
FADE_MS=220     # total fade time (ms)
FADE_STEPS=10   # more steps = smoother

# ---------------- utils ----------------
monitors_json() {
  if hyprctl monitors all -j >/dev/null 2>&1; then
    hyprctl monitors all -j
  else
    hyprctl monitors -j
  fi
}

has_external_active() {
  monitors_json | jq --arg INTERNAL "$INTERNAL" '
    [.[] | select(.name != $INTERNAL and (.disabled|not))] | length > 0
  '
}

internal_disabled() {
  monitors_json | jq -r --arg INTERNAL "$INTERNAL" '
    if any(.[]; .name==$INTERNAL) then
      (.[] | select(.name==$INTERNAL) | .disabled)
    else
      "true"
    end
  '
}

# ------------ brightness / fade ----------
# Returns a usable brightness device or empty if none.
detect_backlight_dev() {
  # Prefer brightnessctl discovery; fallback to /sys/class/backlight
  if [[ -n "$BRIGHT_BIN" ]]; then
    # brightnessctl --machine-readable lists devices; pick first backlight
    local dev
    dev="$("$BRIGHT_BIN" -m | awk -F, '$2 ~ /backlight/ {print $1; exit}')" || true
    printf '%s' "$dev"
    return
  fi
  # fallback sysfs
  local sysdev
  sysdev="$(ls -1 /sys/class/backlight 2>/dev/null | head -n1 || true)"
  printf '%s' "$sysdev"
}

# Read current brightness percentage (0-100) using brightnessctl or sysfs.
get_brightness_pct() {
  if [[ -n "$BRIGHT_BIN" ]]; then
    "$BRIGHT_BIN" -m | awk -F, '$2 ~ /backlight/ {print $4}' | tr -d '()%'
    return
  fi
  local dev="$1"
  [[ -z "$dev" ]] && { echo 100; return; }
  local cur max
  cur="$(cat "/sys/class/backlight/$dev/brightness" 2>/dev/null || echo 1)"
  max="$(cat "/sys/class/backlight/$dev/max_brightness" 2>/dev/null || echo 1)"
  awk -v c="$cur" -v m="$max" 'BEGIN{printf "%.0f", (c*100.0)/m}'
}

set_brightness_pct() {
  local pct="$1"
  if [[ -n "$BRIGHT_BIN" ]]; then
    "$BRIGHT_BIN" set "${pct}%">/dev/null 2>&1 || true
    return
  fi
  # sysfs fallback (may require permissions)
  local dev="$2"
  [[ -z "$dev" ]] && return
  local max
  max="$(cat "/sys/class/backlight/$dev/max_brightness" 2>/dev/null || echo 1)"
  # round to int
  local val
  val=$(awk -v p="$pct" -v m="$max" 'BEGIN{printf "%d", (p*m/100.0)}')
  echo "$val" | sudo tee "/sys/class/backlight/$dev/brightness" >/dev/null 2>&1 || true
}

fade_to() {
  # fade from current to target percentage
  local target="$1"
  local dev sysdev cur step sleep_ms inc i val
  sysdev="$(detect_backlight_dev)"
  cur="$(get_brightness_pct "$sysdev")"
  [[ -z "$cur" ]] && cur=100

  step=$(( (target - cur) / FADE_STEPS ))
  # If step becomes 0 due to integer math, use ±1 to ensure progress
  if [[ "$step" -eq 0 && "$cur" -ne "$target" ]]; then
    if (( target > cur )); then step=1; else step=-1; fi
  fi

  sleep_ms=$(( FADE_MS / (FADE_STEPS>0?FADE_STEPS:1) ))
  val="$cur"

  for (( i=0; i<FADE_STEPS; i++ )); do
    val=$(( val + step ))
    # clamp 0..100
    (( val < 0 )) && val=0
    (( val > 100 )) && val=100
    set_brightness_pct "$val" "$sysdev"
    sleep "$(awk -v ms="$sleep_ms" 'BEGIN{printf "%.3f", ms/1000.0}')"
  done

  # Ensure exact target at the end
  set_brightness_pct "$target" "$sysdev"
}

# ------------- enable/disable ------------
enable_internal() {
  hyprctl keyword monitor "${INTERNAL},${EXPLICIT_MODE},${EXPLICIT_POS},${EXPLICIT_SCALE}" >/dev/null 2>&1 || \
  hyprctl keyword monitor "${INTERNAL},preferred,auto,1" >/dev/null 2>&1 || true

  # DPMS poke + brief wait so the panel binds before fade-in
  hyprctl dispatch dpms on "${INTERNAL}" >/dev/null 2>&1 || true
  sleep 0.15

  # Fade in (to 100%)
  fade_to 100
}

disable_internal() {
  # Fade out first (to 0%), then disable the output
  fade_to 0
  hyprctl keyword monitor "${INTERNAL},disable" >/dev/null
}

# --------------- waybar JSON --------------
status_json() {
  local ext disabled text tooltip class
  ext="$(has_external_active)"
  disabled="$(internal_disabled)"

  if [[ "$ext" == "false" ]]; then
    text="󰌢"
    tooltip="Laptop display only. No external connected."
    class="laptop-only"
  else
    if [[ "$disabled" == "true" ]]; then
      text="󰍹"
      tooltip="Internal display is OFF. Click to enable."
      class="external-only"
    else
      text="󰍺"
      tooltip="Both displays active. Click to disable internal."
      class="dual"
    fi
  fi

  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$class"
}

toggle() {
  local ext disabled
  ext="$(has_external_active)"

  if [[ "$ext" == "false" ]]; then
    [[ -n "$NOTIFY_BIN" ]] && "$NOTIFY_BIN" "Monitor toggle" "No external display detected. Nothing to do."
    exit 0
  fi

  disabled="$(internal_disabled)"
  if [[ "$disabled" == "true" ]]; then
    enable_internal
    [[ -n "$NOTIFY_BIN" ]] && "$NOTIFY_BIN" "Monitor toggle" "Internal display enabled (fade-in)."
  else
    disable_internal
    [[ -n "$NOTIFY_BIN" ]] && "$NOTIFY_BIN" "Monitor toggle" "Internal display disabled (fade-out)."
  fi
  pkill -RTMIN+5 waybar || true
}

case "${1:-}" in
  --toggle) toggle ;;
  --status|"") status_json ;;
  *) echo "Usage: $0 [--toggle|--status]"; exit 2 ;;
esac
