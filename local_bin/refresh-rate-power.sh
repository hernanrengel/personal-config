#!/usr/bin/env bash
# G14 según el cargador:
#   - Pantalla interna: 120 Hz enchufada, 60 Hz con batería (el OLED ahorra bastante).
#   - Perfil asusd: Balanced enchufada, Quiet con batería (solo al cambiar de estado,
#     así no pisa lo que elijas con Fn+F5 mientras tanto).
# Se lanza con exec-once desde hyprland.conf y escucha los eventos del cargador.
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INTERNAL="eDP-1"
MODE_AC="2880x1800@120"
MODE_BAT="2880x1800@60"
POS="2560x0"
SCALE="1.6"
AC_ONLINE="/sys/class/power_supply/ACAD/online"
PROFILE_AC="Balanced"
PROFILE_BAT="Quiet"
LAST_AC=""

on_ac() { [ "$(cat "$AC_ONLINE" 2>/dev/null)" = "1" ]; }

apply_profile() {
    local ac=0
    on_ac && ac=1
    [ "$ac" = "$LAST_AC" ] && return 0
    LAST_AC="$ac"

    local profile="$PROFILE_BAT"
    [ "$ac" = "1" ] && profile="$PROFILE_AC"
    asusctl profile set "$profile" >/dev/null 2>&1 || return 0
    echo -e "${GREEN}Perfil asusd: ${profile}${NC}"
}

apply() {
    # Si la pantalla interna está apagada (solo monitor externo), no la reactives
    hyprctl monitors -j | grep -q "\"name\": \"$INTERNAL\"" || return 0

    local mode="$MODE_BAT"
    on_ac && mode="$MODE_AC"

    # Evitar recargas si ya está en ese modo
    local hz="${mode##*@}"
    if hyprctl monitors -j | python3 -c "
import json, sys
m = [m for m in json.load(sys.stdin) if m['name'] == '$INTERNAL']
sys.exit(0 if m and round(m[0]['refreshRate']) == $hz else 1)"; then
        return 0
    fi

    echo -e "${YELLOW}Cambiando $INTERNAL a ${mode}${NC}"
    hyprctl keyword monitor "$INTERNAL,$mode,$POS,$SCALE" >/dev/null
    echo -e "${GREEN}Listo${NC}"
}

apply_profile
apply

# udevadm emite una línea por cada cambio en power_supply (cargador o batería);
# apply()/apply_profile() no hacen nada si el estado no cambió
udevadm monitor --udev --subsystem-match=power_supply | while read -r _; do
    sleep 1
    apply_profile
    apply
done
