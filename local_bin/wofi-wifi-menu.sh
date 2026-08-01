#!/usr/bin/env bash
# WiFi menu using wofi + nmcli

WOFI_STYLE="$HOME/.config/wofi/style.css"

# ── Icons ──────────────────────────────────────────────────────
icon_wifi_full="󰤨"
icon_wifi_high="󰤥"
icon_wifi_med="󰤢"
icon_wifi_low="󰤟"
icon_wifi_off="󰤭"
icon_lock=" "
icon_open=" "
icon_connected="󰄬 "
icon_toggle_on="󰖩  Enable WiFi"
icon_toggle_off="󰖪  Disable WiFi"
icon_rescan="󰑐  Rescan"
icon_disconnect="󱘖  Disconnect"

# ── Signal strength → icon ─────────────────────────────────────
signal_icon() {
    local signal=$1
    if   [ "$signal" -ge 75 ]; then echo "$icon_wifi_full"
    elif [ "$signal" -ge 50 ]; then echo "$icon_wifi_high"
    elif [ "$signal" -ge 25 ]; then echo "$icon_wifi_med"
    else                             echo "$icon_wifi_low"
    fi
}

# ── WiFi state ─────────────────────────────────────────────────
wifi_state=$(nmcli -fields WIFI g | tail -1 | tr -d ' ')
current_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '/^yes/{print $2}' | head -1)

# ── Build menu ─────────────────────────────────────────────────
build_menu() {
    # Toggle option
    if [[ "$wifi_state" == "enabled" ]]; then
        echo "$icon_toggle_off"
    else
        echo "$icon_toggle_on"
        return
    fi

    # Disconnect option (if connected)
    if [[ -n "$current_ssid" ]]; then
        echo "$icon_disconnect current: $current_ssid"
    fi

    echo "$icon_rescan"
    echo "---"

    # Scan networks
    nmcli --fields SSID,SIGNAL,SECURITY,IN-USE dev wifi list 2>/dev/null \
        | tail -n +2 \
        | sed '/^--/d' \
        | sort -t' ' -k2 -rn \
        | while IFS= read -r line; do
            ssid=$(echo "$line"     | awk '{$NF=""; $(NF-1)=""; $(NF-2)=""; sub(/[[:space:]]+$/, ""); print}' | sed 's/^[[:space:]]*//')
            signal=$(echo "$line"   | awk '{print $(NF-2)}')
            security=$(echo "$line" | awk '{print $(NF-1)}')
            in_use=$(echo "$line"   | awk '{print $NF}')

            # Skip empty SSIDs
            [[ -z "$ssid" ]] && continue

            sig_icon=$(signal_icon "${signal:-0}")

            if [[ "$security" == "--" || -z "$security" ]]; then
                sec_icon="$icon_open"
            else
                sec_icon="$icon_lock"
            fi

            if [[ "$in_use" == "*" ]]; then
                echo "${icon_connected}${sig_icon} ${sec_icon} ${ssid}"
            else
                echo "${sig_icon} ${sec_icon} ${ssid}"
            fi
        done
}

# ── Show wofi ──────────────────────────────────────────────────
chosen=$(build_menu | grep -v '^---$' | wofi \
    --dmenu \
    --style "$WOFI_STYLE" \
    --prompt "  WiFi" \
    --width 380 \
    --height 400 \
    --cache-file /dev/null \
    --no-actions \
    --define=matching=fuzzy \
    --insensitive)

[[ -z "$chosen" ]] && exit 0

# ── Handle selection ───────────────────────────────────────────
case "$chosen" in
    "$icon_toggle_off"*)
        nmcli radio wifi off
        ;;
    "$icon_toggle_on"*)
        nmcli radio wifi on
        ;;
    "$icon_rescan"*)
        nmcli dev wifi rescan 2>/dev/null
        sleep 2
        exec "$0"
        ;;
    "$icon_disconnect"*)
        nmcli dev disconnect "$(nmcli -t -f DEVICE,STATE dev | awk -F: '/wireless.*connected/{print $1}' | head -1)"
        ;;
    *)
        # Extract SSID — strip leading icons and spaces
        ssid=$(echo "$chosen" | sed 's/^[󰄬󰤨󰤥󰤢󰤟 ]*//; s/^ *\(󰔒\|󰒃\) //; s/^ *//')
        # More aggressive strip: remove all non-ASCII icon chars at start
        ssid=$(echo "$chosen" | sed 's/^[^a-zA-Z0-9_\-\.\(\)\[\]\{\}@#$%&*!]*//' | sed 's/^ *//')

        [[ -z "$ssid" ]] && exit 0

        # Check if already a known connection
        if nmcli connection show "$ssid" &>/dev/null; then
            nmcli connection up "$ssid"
        else
            # Ask for password if network is secured
            security=$(nmcli --fields SSID,SECURITY dev wifi list | grep -F "$ssid" | awk '{print $NF}' | head -1)
            if [[ "$security" != "--" && -n "$security" ]]; then
                password=$(wofi \
                    --dmenu \
                    --style "$WOFI_STYLE" \
                    --prompt "  Password for $ssid" \
                    --width 380 \
                    --height 80 \
                    --password \
                    --cache-file /dev/null)
                [[ -z "$password" ]] && exit 0
                nmcli dev wifi connect "$ssid" password "$password"
            else
                nmcli dev wifi connect "$ssid"
            fi
        fi
        ;;
esac
