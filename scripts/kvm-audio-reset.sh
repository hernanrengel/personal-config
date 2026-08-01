#!/bin/bash
# Reset audio services after KVM switch
# Created by Antigravity

# Log file for debugging udev execution
LOG_FILE="/home/brosso3d/.logs/kvm-audio-reset.log"
mkdir -p "/home/brosso3d/.logs"
echo "[$(date)] KVM audio reset triggered" >> "$LOG_FILE"

# Wait for KVM USB devices to initialize completely
sleep 2.5

# Force user environment variables
export USER="brosso3d"
export HOME="/home/brosso3d"
export XDG_RUNTIME_DIR="/run/user/1000"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

# Restart PipeWire and WirePlumber user services
systemctl --user restart pipewire pipewire-pulse wireplumber >> "$LOG_FILE" 2>&1
echo "[$(date)] PipeWire restarted" >> "$LOG_FILE"

# Settle down
sleep 2.0

# Set default sink to Nvidia HDMI monitor
pactl set-default-sink alsa_output.pci-0000_01_00.1.hdmi-stereo >> "$LOG_FILE" 2>&1
echo "[$(date)] Default sink set to Nvidia HDMI" >> "$LOG_FILE"

# Find the exact Redragon microphone source name dynamically
REDRAGON_SOURCE=$(pactl list sources short | awk '{print $2}' | grep -i "REDRAGON" | head -n1)
INTERNAL_SOURCE="alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source"

if [ -n "$REDRAGON_SOURCE" ]; then
    pactl set-default-source "$REDRAGON_SOURCE" >> "$LOG_FILE" 2>&1
    echo "[$(date)] Default source set to Redragon: $REDRAGON_SOURCE" >> "$LOG_FILE"
else
    pactl set-default-source "$INTERNAL_SOURCE" >> "$LOG_FILE" 2>&1
    echo "[$(date)] Default source set to internal mic: $INTERNAL_SOURCE" >> "$LOG_FILE"
fi

# Reset Chrome's audio subsystem to clean up dead links
pkill -f "audio.mojom.AudioService" >> "$LOG_FILE" 2>&1
echo "[$(date)] Chrome audio service reset signal sent" >> "$LOG_FILE"
echo "[$(date)] Reset complete!" >> "$LOG_FILE"
